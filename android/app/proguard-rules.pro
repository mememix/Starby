# 高德地图 ProGuard 规则
-keep class com.amap.api.** { *; }
-keep class com.autonavi.** { *; }
-keep class com.loc.** { *; }
-dontwarn com.amap.api.**
-dontwarn com.autonavi.**
-dontwarn com.loc.**

# 高德定位
-keep class com.amap.api.location.** { *; }
-keep class com.amap.api.fence.** { *; }
-keep class com.amap.api.trace.** { *; }

# 高德地图
-keep class com.amap.api.maps.** { *; }
-keep class com.amap.api.mapcore.** { *; }
-keep class com.autonavi.amap.mapcore.** { *; }
-keep class com.autonavi.ae.gmap.** { *; }
-keep class com.autonavi.base.amap.mapcore.** { *; }
-keep class com.autonavi.base.ae.gmap.** { *; }
