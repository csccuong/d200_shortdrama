# Preserve RoomDatabase generated *_Impl classes and their no-arg constructors under R8 Full Mode
-keep class * extends androidx.room.RoomDatabase {
    <init>();
    *;
}
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# Preserve App Startup Initializer constructors
-keep class * extends androidx.startup.Initializer {
    <init>(...);
}
