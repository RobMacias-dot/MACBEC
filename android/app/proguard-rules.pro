# google_mlkit_text_recognition ships optional recognizers (Chinese, Devanagari,
# Japanese, Korean) as separate artifacts. This app only depends on the base
# recognizer, so R8 can't resolve these classes at compile time even though
# they're only reachable via reflection/options the app never uses.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
