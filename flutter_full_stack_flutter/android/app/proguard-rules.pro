# ONNX Runtime encontra as próprias classes Java por nome, de dentro do código
# nativo, via JNI FindClass. O R8 não enxerga essa referência: para ele as
# classes não são usadas, então renomeia ou remove. Em runtime o FindClass
# devolve null e a camada JNI aborta o processo:
#
#   JNI DETECTED ERROR IN APPLICATION: java_class == null
#       in call to GetMethodID
#       from ai.onnxruntime.OrtSession.run(...)
#
# Só acontece em release, porque é lá que o R8 roda — e só no momento de
# pontuar, que é quando a sessão é executada pela primeira vez.
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }

# Qualquer classe com método nativo: o nome é o contrato com o lado C++.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
