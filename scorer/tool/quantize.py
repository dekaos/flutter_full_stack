"""Quantiza o ONNX exportado para int8 (dynamic), medindo o tamanho final."""
import sys, pathlib
from onnxruntime.quantization import quantize_dynamic, QuantType
from onnxruntime.quantization.shape_inference import quant_pre_process

lang = sys.argv[1] if len(sys.argv) > 1 else "en"
b = pathlib.Path("build")
src, pre, dst = b / f"phoneme_{lang}.onnx", b / f"phoneme_{lang}.pre.onnx", b / f"phoneme_{lang}.int8.onnx"
quant_pre_process(str(src), str(pre), skip_symbolic_shape=True)
quantize_dynamic(str(pre), str(dst), weight_type=QuantType.QInt8)
total = sum(f.stat().st_size for f in b.glob(f"phoneme_{lang}.int8.onnx*"))
print("int8 MB:", round(total / 1e6, 1))
