"""Exporta o modelo de fonemas para ONNX int8, pronto para o app.

    python tool/export_onnx.py en

A weight norm da convolucao posicional precisa sair antes do export: ela
calcula o peso em runtime (g * v/||v||), e o quantizador do onnxruntime so
aceita pesos que sejam initializers -- com ela, a quantizacao falha em
"Expected .../Mul_output_0 to be an initializer".
"""
import pathlib
import sys

import torch
from onnxruntime.quantization import QuantType, quantize_dynamic
from onnxruntime.quantization.shape_inference import quant_pre_process
from transformers import AutoModelForCTC

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
from gop.acoustic import MODEL_REVISION, MODELS, revision_for  # noqa: E402

# So os MatMul. Quantizar Conv produz ConvInteger, cujo kernel do onnxruntime
# nao aceita peso int8 -- no Android o app morre ao abrir a sessao com
# "Could not find an implementation for ConvInteger". As convolucoes do
# extrator de features do wav2vec2 sao ~4M dos 316M de parametros, entao
# deixa-las em float quase nao muda o tamanho e preserva a parte do modelo
# mais sensivel a quantizacao.
QUANTIZED_OPS = ["MatMul"]


def strip_weight_norm(model: torch.nn.Module) -> None:
    conv = model.wav2vec2.encoder.pos_conv_embed.conv
    try:
        torch.nn.utils.parametrize.remove_parametrizations(conv, "weight")
    except (ValueError, AttributeError):
        torch.nn.utils.remove_weight_norm(conv)


def main() -> int:
    lang = sys.argv[1] if len(sys.argv) > 1 else "en"
    out = pathlib.Path("build")
    out.mkdir(exist_ok=True)

    model_id = MODELS[lang]
    model = AutoModelForCTC.from_pretrained(model_id, revision=revision_for(model_id)).eval()
    strip_weight_norm(model)
    print("params:", round(sum(p.numel() for p in model.parameters()) / 1e6, 1), "M")

    fp32 = out / f"phoneme_{lang}.onnx"
    torch.onnx.export(
        model, (torch.randn(1, 16_000 * 3),), str(fp32),
        input_names=["input_values"], output_names=["logits"],
        dynamic_axes={"input_values": {1: "samples"}, "logits": {1: "frames"}},
        opset_version=17, dynamo=True,
    )

    pre = out / f"phoneme_{lang}.pre.onnx"
    quant_pre_process(str(fp32), str(pre), skip_symbolic_shape=True)
    int8 = out / f"phoneme_{lang}_{MODEL_REVISION}.int8.onnx"
    quantize_dynamic(
        str(pre), str(int8),
        weight_type=QuantType.QInt8,
        op_types_to_quantize=QUANTIZED_OPS,
    )
    pre.unlink(missing_ok=True)

    # Falha aqui e melhor do que falhar no aparelho do aluno.
    import collections

    import onnx
    ops = collections.Counter(
        n.op_type for n in onnx.load(str(int8), load_external_data=False).graph.node
    )
    unsupported = [op for op in ops if op == "ConvInteger"]
    if unsupported:
        raise SystemExit(f"grafo tem ops sem kernel no Android: {unsupported}")
    print("MatMulInteger:", ops["MatMulInteger"], "| Conv:", ops["Conv"])

    def size(stem: pathlib.Path) -> float:
        return sum(f.stat().st_size for f in out.glob(f"{stem.name}*")) / 1e6

    print("fp32 MB:", round(size(fp32), 1))
    print("int8 MB:", round(size(int8), 1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
