# Room 2.2.5 creates this WorkManager database with Class.newInstance().
# Retain the no-arg constructor removed by release R8; leave other code optimized.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}

# ML Kit discovers this manifest registrar with getDeclaredConstructor().
# Its class survived R8, but its reflective no-arg constructor did not.
-keep class com.google.mlkit.common.internal.CommonComponentRegistrar {
    public <init>();
}
