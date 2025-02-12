# Hướng dẫn chi tiết lấy file APK của ứng dụng đã cài trên máy Android

Bài viết này tổng hợp nội dung từ bài viết trên Viblo "[Mẹo lấy file APK của ứng dụng đã cài trên máy Android](https://viblo.asia/p/meo-lay-file-apk-cua-ung-dung-da-cai-tren-may-android-PwlVmyv0V5Z)" và cung cấp hướng dẫn chi tiết để bạn có thể trích xuất file APK của bất kỳ ứng dụng nào đã cài trên thiết bị Android mà không cần root.

---

## Mục lục

1. [Giới thiệu](#giới-thiệu)
2. [Yêu cầu](#yêu-cầu)
3. [Phương pháp 1: Sử dụng ứng dụng APK Extractor](#phương-pháp-1-sử-dụng-ứng-dụng-apk-extractor)
   - [Bước 1: Cài đặt ứng dụng](#bước-1-cài-đặt-ứng-dụng)
   - [Bước 2: Trích xuất file APK](#bước-2-trích-xuất-file-apk)
4. [Phương pháp 2: Sử dụng ADB trên máy tính](#phương-pháp-2-sử-dụng-adb-trên-máy-tính)
   - [Bước 1: Cài đặt và cấu hình ADB](#bước-1-cài-đặt-và-cấu-hình-adb)
   - [Bước 2: Xác định tên gói của ứng dụng](#bước-2-xác-định-tên-gói-của-ứng-dụng)
   - [Bước 3: Lấy đường dẫn file APK](#bước-3-lấy-đường-dẫn-file-apk)
   - [Bước 4: Sao chép file APK về máy tính](#bước-4-sao-chép-file-apk-về-máy-tính)
5. [Lưu ý khi thực hiện](#lưu-ý-khi-thực-hiện)
6. [Kết luận](#kết-luận)

---

## Giới thiệu

Việc lấy file APK của một ứng dụng đã cài đặt trên thiết bị Android giúp bạn có thể:

- **Sao lưu ứng dụng**: Dùng để cài đặt lại khi cần.
- **Chia sẻ ứng dụng**: Gửi cho bạn bè hoặc sử dụng trên thiết bị khác.
- **Phân tích ứng dụng**: Có thể dùng để kiểm tra hoặc nghiên cứu.

Bài viết dưới đây giới thiệu hai phương pháp phổ biến:

- Sử dụng **APK Extractor** – giải pháp đơn giản qua giao diện người dùng.
- Sử dụng **ADB** – giải pháp dành cho người dùng có kinh nghiệm với dòng lệnh và cần kiểm soát chi tiết hơn.

---

## Yêu cầu

- **Đối với Phương pháp 1**:

  - Một thiết bị Android đã cài đặt ứng dụng cần trích xuất.
  - Kết nối Internet để tải ứng dụng APK Extractor từ Google Play Store.

- **Đối với Phương pháp 2**:
  - Máy tính (Windows, macOS hoặc Linux) đã cài đặt **Android SDK Platform Tools** (bao gồm ADB).
  - Cáp USB để kết nối điện thoại với máy tính.
  - Thiết bị Android với chế độ **USB Debugging** đã được kích hoạt.

---

## Phương pháp 1: Sử dụng ứng dụng APK Extractor

### Bước 1: Cài đặt ứng dụng

1. Mở **Google Play Store** trên điện thoại.
2. Tìm kiếm từ khóa "**APK Extractor**".
3. Chọn và cài đặt một ứng dụng APK Extractor được đánh giá cao (ví dụ: "APK Extractor" của các nhà phát triển uy tín).

### Bước 2: Trích xuất file APK

1. Mở ứng dụng **APK Extractor** sau khi cài đặt.
2. Ứng dụng sẽ liệt kê toàn bộ các ứng dụng đã cài trên điện thoại của bạn.
3. Tìm và chọn ứng dụng mà bạn muốn lấy file APK.
4. Chạm vào tên ứng dụng để tiến hành trích xuất file APK.
5. File APK sẽ được lưu vào thư mục mặc định trên điện thoại (thường là `/sdcard/APKExtractor/`), sau đó bạn có thể chuyển file này sang máy tính hoặc nơi lưu trữ khác theo nhu cầu.

---

## Phương pháp 2: Sử dụng ADB trên máy tính

### Bước 1: Cài đặt và cấu hình ADB

1. Tải về và cài đặt **Android SDK Platform Tools** từ trang chủ của [Android Developers](https://developer.android.com/studio/releases/platform-tools).
2. Kết nối điện thoại với máy tính bằng cáp USB.
3. Trên điện thoại, trong phần **Cài đặt > Tuỳ chọn nhà phát triển**, bật chế độ **USB Debugging**.

### Bước 2: Xác định tên gói của ứng dụng

Nếu bạn không chắc chắn về tên gói của ứng dụng, bạn có thể liệt kê tất cả các ứng dụng đã cài bằng lệnh sau:

```bash
adb shell pm list packages
```

Lệnh này sẽ hiển thị danh sách tên gói của tất cả các ứng dụng đã cài đặt.

### Bước 3: Lấy đường dẫn file APK

1. Giả sử bạn đã biết tên gói của ứng dụng (ví dụ `com.example.app`), hãy chạy lệnh sau để lấy đường dẫn:
   ```bash
   adb shell pm path com.example.app
   ```
2. Lệnh này sẽ trả về đường dẫn file APK. Ví dụ:
   ```
   package:/data/app/com.example.app-1/base.apk
   ```

### Bước 4: Sao chép file APK về máy tính

1. Sử dụng lệnh `adb pull` để sao chép file APK từ thiết bị về máy tính. Ví dụ:
   ```bash
   adb pull /data/app/com.example.app-1/base.apk
   ```
2. File APK sẽ được lưu vào thư mục hiện tại mà bạn đang thao tác trên máy tính. Bạn có thể di chuyển hoặc đổi tên file theo ý muốn.

---

## Lưu ý khi thực hiện

- **Bản quyền và quyền riêng tư**: Chỉ sử dụng các hướng dẫn này cho mục đích cá nhân, sao lưu hay nghiên cứu. Việc trích xuất và chia sẻ file APK có thể vi phạm điều khoản sử dụng hoặc bản quyền của ứng dụng.
- **Khả năng truy cập**: Một số ứng dụng có thể bảo vệ file APK của mình và không cho phép trích xuất dễ dàng qua ADB hoặc ứng dụng APK Extractor.
- **Thiết bị không root**: Các phương pháp trên được áp dụng cho thiết bị không cần quyền root. Nếu ứng dụng được cài đặt ở vị trí hệ thống hoặc có bảo vệ đặc biệt, bạn có thể cần quyền root để truy cập.

---

## Kết luận

Qua hai phương pháp trên, bạn có thể dễ dàng lấy file APK của các ứng dụng đã cài đặt trên thiết bị Android:

- **APK Extractor**: Phù hợp với người dùng không quen thuộc với dòng lệnh, thao tác đơn giản qua giao diện ứng dụng.
- **ADB**: Dành cho người dùng có kinh nghiệm, cho phép kiểm soát chi tiết hơn và thực hiện trên máy tính.

Hy vọng hướng dẫn này sẽ giúp bạn thực hiện thành công việc trích xuất file APK theo nhu cầu của mình.

---

_Tham khảo: [Mẹo lấy file APK của ứng dụng đã cài trên máy Android](https://viblo.asia/p/meo-lay-file-apk-cua-ung-dung-da-cai-tren-may-android-PwlVmyv0V5Z)_
