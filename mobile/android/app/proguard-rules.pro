# Room 2.2.5 creates this WorkManager database with Class.newInstance().
# Retain the no-arg constructor removed by release R8; leave other code optimized.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
