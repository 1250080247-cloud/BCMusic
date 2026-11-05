# Keep classes used through reflection by NewPipeExtractor and Rhino.
-keep class org.schabi.newpipe.extractor.timeago.patterns.** { *; }
-keep class org.mozilla.javascript.** { *; }
-keep class org.mozilla.classfile.ClassFileWriter { *; }

# Rhino uses its interpreter on Android. These optional desktop paths match the
# rules in TeamNewPipe/NewPipe's Android app.
-dontwarn org.mozilla.javascript.JavaToJSONConverters
-dontwarn org.mozilla.javascript.tools.**
-dontwarn javax.script.**
-dontwarn jdk.dynalink.**
