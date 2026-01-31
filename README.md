# Emergency Drive Wipe Tool

Công cụ xóa ổ cứng khẩn cấp cho Windows - **DỮ LIỆU KHÔNG THỂ KHÔI PHỤC**

## Cấu trúc

```
Wipe-disk/
├── EmergencyWipe.ps1      # Xóa ổ đĩa dữ liệu (D:, E:...)
├── WipeNow.bat            # Launcher chính
├── QuickWipe.bat          # Xóa nhanh
│
└── PreOS-Wipe/            # XÓA CẢ Ổ HỆ THỐNG (C:)
    ├── InstantWipe.bat    # Một click - reboot và xóa tất cả
    ├── PreOSWipe.ps1      # Script chính với tùy chọn
    ├── PreOS-WipeNow.bat  # Launcher PreOS
    └── CancelWipe.bat     # Hủy thiết lập
```

## Tính năng

- Nhiều phương pháp xóa bảo mật
- Xác nhận 3 lần trước khi xóa
- Hiển thị tiến trình
- Bảo vệ ổ đĩa hệ thống
- Hỗ trợ dòng lệnh và giao diện tương tác

## Phương pháp xóa

| Phương pháp | Mô tả | Độ an toàn | Thời gian |
|-------------|-------|------------|-----------|
| **Quick** | Xóa files + cipher + format | Trung bình | Nhanh |
| **Zero** | Ghi đè toàn bộ bằng 0 | Cao | Trung bình |
| **DoD** | DoD 5220.22-M (3 passes) | Rất cao | Chậm |
| **Gutmann** | Gutmann 35 passes | Cực cao | Rất chậm |
| **Random** | Ghi đè random (tùy chỉnh) | Tùy chỉnh | Tùy chỉnh |

## Cách sử dụng

### Cách 1: Double-click file batch

1. **WipeNow.bat** - Chạy với giao diện tương tác đầy đủ
2. **QuickWipe.bat** - Xóa nhanh (chế độ Quick)

### Cách 2: Dòng lệnh PowerShell

```powershell
# Liệt kê ổ đĩa
.\EmergencyWipe.ps1 -ListDrives

# Xóa ổ D: với phương pháp DoD (mặc định)
.\EmergencyWipe.ps1 -DriveLetter D -Method DoD

# Xóa nhanh ổ E:
.\EmergencyWipe.ps1 -DriveLetter E -Method Quick

# Xóa với Gutmann 35-pass (cực kỳ an toàn)
.\EmergencyWipe.ps1 -DriveLetter D -Method Gutmann

# Xóa với random 7 passes
.\EmergencyWipe.ps1 -DriveLetter D -Method Random -Passes 7

# Xóa không cần xác nhận (NGUY HIỂM!)
.\EmergencyWipe.ps1 -DriveLetter D -Method DoD -Force
```

### Tham số

| Tham số | Mô tả | Mặc định |
|---------|-------|----------|
| `-DriveLetter` | Ký tự ổ đĩa cần xóa (VD: D, E, F) | Bắt buộc |
| `-Method` | Phương pháp xóa (Quick/Zero/DoD/Gutmann/Random) | DoD |
| `-Passes` | Số lần ghi đè (chỉ dùng với Random) | 3 |
| `-Force` | Bỏ qua xác nhận (NGUY HIỂM!) | False |
| `-ListDrives` | Liệt kê tất cả ổ đĩa | - |

## Yêu cầu hệ thống

- Windows 10/11
- Quyền Administrator
- PowerShell 5.0+

## Cảnh báo

```
╔══════════════════════════════════════════════════════════════════╗
║  !!! CẢNH BÁO QUAN TRỌNG !!!                                     ║
║                                                                  ║
║  - Dữ liệu sau khi xóa KHÔNG THỂ KHÔI PHỤC bằng bất kỳ cách nào  ║
║  - Kiểm tra kỹ ổ đĩa trước khi xóa                               ║
║  - Backup dữ liệu quan trọng trước khi sử dụng                   ║
║  - Không thể xóa ổ đĩa hệ thống khi Windows đang chạy           ║
║  - Sử dụng đúng mục đích, tác giả không chịu trách nhiệm         ║
╚══════════════════════════════════════════════════════════════════╝
```

## Xóa ổ đĩa hệ thống (PreOS Wipe)

Để xóa ổ đĩa chứa Windows (C:), sử dụng **PreOS-Wipe**:

```
1. Chạy PreOS-Wipe/InstantWipe.bat
2. Xác nhận 3 lần
3. Máy tự động khởi động lại
4. Scheduled Task (SYSTEM) chạy TRƯỚC KHI LOGIN
5. DISKPART CLEAN ALL xóa TẤT CẢ ổ cứng
6. Máy tắt sau khi hoàn tất
```

**KHÔNG cần USB boot** - Scheduled Task chạy với SYSTEM account trước login.

Xem thêm: [PreOS-Wipe/README.md](PreOS-Wipe/README.md)

## Mức độ bảo mật

- **Quick**: Đủ cho hầu hết trường hợp thông thường
- **Zero**: Đủ cho dữ liệu cá nhân
- **DoD 5220.22-M**: Tiêu chuẩn quân đội Mỹ, đủ cho dữ liệu nhạy cảm
- **Gutmann**: Tiêu chuẩn cao nhất, dành cho dữ liệu tuyệt mật

## Giấy phép

MIT License - Sử dụng miễn phí, tự chịu trách nhiệm.
