# Add project-specific ProGuard rules here.

# ---------------------------------------------------------------------------
# Crash-trace readability. Keep line numbers so Play can map obfuscated frames
# back to source via the bundled mapping.txt; rename the source-file attribute
# to a constant so the real filename isn't leaked.
# ---------------------------------------------------------------------------
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---------------------------------------------------------------------------
# kotlinx.serialization
#
# core/network/KotlinxJsonConverterFactory resolves serializers reflectively
# via serializer(Type) for EVERY request/response body, so R8 (full mode on
# AGP 9) must keep the generated $serializer classes and Companion.serializer()
# methods. These are the canonical rules from the kotlinx.serialization README.
# The library ships consumer rules too, but we pin them explicitly because a
# miss surfaces only at runtime (SerializationException: Serializer ... not
# found), never at build time.
#
# NB: DTO *property* names may still be obfuscated safely — JSON field names
# are compile-time constants baked into each generated serializer's descriptor
# (or come from @SerialName), independent of the Kotlin property name.
# ---------------------------------------------------------------------------
-keepattributes RuntimeVisibleAnnotations,AnnotationDefault

# Keep the `Companion` field of every @Serializable class.
-if @kotlinx.serialization.Serializable class **
-keepclassmembers class <1> {
    static <1>$Companion Companion;
}

# Keep `serializer()` on the companion object (default or named) of every
# @Serializable class.
-if @kotlinx.serialization.Serializable class ** {
    static **$* *;
}
-keepclassmembers class <2>$<3> {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep `INSTANCE.serializer()` of @Serializable objects.
-if @kotlinx.serialization.Serializable class ** {
    public static ** INSTANCE;
}
-keepclassmembers class <1> {
    public static <1> INSTANCE;
    kotlinx.serialization.KSerializer serializer(...);
}

# ---------------------------------------------------------------------------
# Retrofit 2.11 + OkHttp 4.12 already ship consumer R8 rules; the following are
# belt-and-suspenders for the generic-type reflection Retrofit does on suspend
# service methods, plus dontwarns for optional platform/TLS providers that are
# not on the classpath.
# ---------------------------------------------------------------------------
-keepattributes Signature,InnerClasses,EnclosingMethod,Exceptions
-keepattributes RuntimeVisibleParameterAnnotations,RuntimeInvisibleParameterAnnotations

-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class retrofit2.Response
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation

-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
