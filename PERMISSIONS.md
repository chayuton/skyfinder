# สิทธิ์ที่ต้องเพิ่มหลัง `flutter create`

`flutter create .` จะสร้างโฟลเดอร์ `android/` และ `ios/` ให้ ซึ่งยังไม่มีสิทธิ์
สำหรับ GPS และเซ็นเซอร์ ต้องเติมสองไฟล์นี้เอง ไม่งั้นแอปจะเปิดได้แต่หาตำแหน่งไม่เจอ
และโหมดเล็งจะไม่ขยับ

## Android — `android/app/src/main/AndroidManifest.xml`

วางภายใน `<manifest>` ก่อนแท็ก `<application>`

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />

<!-- ตั้ง required=false เพื่อไม่ให้ Play Store ตัดเครื่องที่ไม่มีเข็มทิศ
     ออกจากการติดตั้ง เพราะแอปยังใช้โหมดปรับเองได้ -->
<uses-feature android:name="android.hardware.sensor.compass" android:required="false" />
<uses-feature android:name="android.hardware.sensor.accelerometer" android:required="false" />
<uses-feature android:name="android.hardware.location.gps" android:required="false" />
```

ใน `android/app/build.gradle` ตรวจว่า `minSdk` เป็น 21 ขึ้นไป (geolocator ต้องการ)

## iOS — `ios/Runner/Info.plist`

วางภายใน `<dict>` ชั้นนอกสุด ข้อความนี้คือสิ่งที่ผู้ใช้เห็นตอนระบบถามสิทธิ์
Apple ปฏิเสธแอปที่เว้นว่าง

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>ใช้พิกัดของคุณเพื่อคำนวณว่าดาวแต่ละดวงอยู่ตรงไหนบนท้องฟ้าจากจุดที่คุณยืน</string>

<key>NSMotionUsageDescription</key>
<string>ใช้เข็มทิศและเซ็นเซอร์เอียงเพื่อบอกว่าคุณกำลังเล็งมือถือไปที่ดาวดวงใด</string>

<key>UISupportedInterfaceOrientations</key>
<array>
  <string>UIInterfaceOrientationPortrait</string>
</array>
```

ใน `ios/Podfile` ตั้ง `platform :ios, '12.0'` ขึ้นไป
