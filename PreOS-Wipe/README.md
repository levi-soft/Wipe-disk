# PreOS Emergency Wipe

Công cụ xóa ổ cứng khẩn cấp kiểu PreOS - **Khởi động lại, chạy từ RAM, xóa TẤT CẢ ổ cứng**

## Cách hoạt động

```
┌─────────────────────────────────────────────────────────────┐
│  1. Chạy tool → Thiết lập cấu hình Safe Mode                │
│  2. Máy tính tự động khởi động lại                          │
│  3. Boot vào Safe Mode (chạy từ RAM tối thiểu)              │
│  4. Script tự động chạy và xóa TẤT CẢ ổ đĩa                │
│  5. Sử dụng DISKPART CLEAN ALL - xóa hoàn toàn              │
│  6. Máy tắt sau khi hoàn tất                                │
└─────────────────────────────────────────────────────────────┘
```

## Các file

| File | Mô tả |
|------|-------|
| `InstantWipe.bat` | **XÓA NGAY** - Một click khởi động lại và xóa tất cả |
| `PreOS-WipeNow.bat` | Launcher với tùy chọn thiết lập/hủy |
| `PreOSWipe.ps1` | Script PowerShell chính với tùy chọn nâng cao |
| `CancelWipe.bat` | Hủy thiết lập (nếu chưa reboot) |

## Sử dụng

### Cách 1: Xóa nhanh nhất (InstantWipe)

```
1. Double-click InstantWipe.bat
2. Xác nhận 3 lần
3. Máy tự động khởi động lại và xóa tất cả
```

### Cách 2: PowerShell với tùy chọn

```powershell
# Thiết lập và khởi động lại để xóa
.\PreOSWipe.ps1 -SetupWipe

# Xóa với 3 lần ghi đè (an toàn hơn)
.\PreOSWipe.ps1 -SetupWipe -Passes 3

# Hủy thiết lập (nếu chưa reboot)
.\PreOSWipe.ps1 -CancelWipe
```

### Cách 3: Hủy nếu đổi ý

```
- Nếu CHƯA reboot: Chạy CancelWipe.bat
- Nếu ĐÃ reboot: TẮT MÁY trong 15 giây đầu
```

## Quy trình xác nhận

Tool yêu cầu xác nhận 3 lần:
1. Nhập `XOA TAT CA`
2. Nhập `KHONG KHOI PHUC`
3. Nhập `TOI HIEU VA DONG Y`

Sau đó có 15 giây để tắt máy trước khi bắt đầu xóa.

## Cảnh báo

```
╔══════════════════════════════════════════════════════════════════╗
║                    !!! CẢNH BÁO TỐI QUAN TRỌNG !!!               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  • Tool này XÓA TẤT CẢ ổ cứng, bao gồm cả ổ Windows (C:)       ║
║  • Sau khi reboot, quá trình xóa TỰ ĐỘNG và KHÔNG THỂ DỪNG     ║
║  • Dữ liệu KHÔNG THỂ KHÔI PHỤC bằng bất kỳ phương pháp nào     ║
║  • Máy tính sẽ không thể boot sau khi xóa                       ║
║  • Cần cài lại Windows hoàn toàn                                 ║
║                                                                  ║
║  CHỈ SỬ DỤNG KHI THỰC SỰ CẦN XÓA KHẨN CẤP!                      ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

## Yêu cầu

- Windows 10/11
- Quyền Administrator
- KHÔNG cần USB boot hay công cụ bên ngoài

## So sánh với tool thường

| Tính năng | EmergencyWipe (thường) | PreOS Wipe |
|-----------|------------------------|------------|
| Xóa ổ dữ liệu (D:, E:...) | ✅ | ✅ |
| Xóa ổ hệ thống (C:) | ❌ | ✅ |
| Cần USB boot | Không | Không |
| Chạy từ RAM | Không | Có |
| Xóa khi Windows đang chạy | Có | Không (reboot) |

## License

MIT License - Sử dụng miễn phí, tự chịu trách nhiệm.
