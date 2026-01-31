# PreOS Emergency Wipe

Công cụ xóa ổ cứng khẩn cấp - **Khởi động lại, chạy TRƯỚC LOGIN, xóa TẤT CẢ ổ cứng**

## Cách hoạt động

```
┌─────────────────────────────────────────────────────────────┐
│  1. Chạy tool → Tạo Scheduled Task (SYSTEM, At Startup)     │
│  2. Máy tính tự động khởi động lại                          │
│  3. Windows boot → Task chạy TRƯỚC KHI LOGIN               │
│  4. DISKPART CLEAN xóa MBR/GPT (máy mất boot ngay)         │
│  5. DISKPART CLEAN ALL xóa toàn bộ dữ liệu                 │
│  6. Máy tắt sau khi hoàn tất                                │
└─────────────────────────────────────────────────────────────┘
```

**Tại sao hoạt động?**
- Scheduled Task với SYSTEM account chạy trước khi user login
- DISKPART CLEAN xóa MBR/GPT ngay lập tức → máy không thể boot lại
- DISKPART CLEAN ALL ghi đè zeros lên toàn bộ ổ đĩa

## Các file

| File | Mô tả |
|------|-------|
| `InstantWipe.bat` | **XÓA NGAY** - Một click, reboot và xóa tất cả |
| `PreOS-WipeNow.bat` | Launcher với menu |
| `PreOSWipe.ps1` | Script PowerShell với tùy chọn nâng cao |
| `CancelWipe.bat` | Hủy thiết lập (nếu chưa reboot) |

## Sử dụng

### Cách 1: Xóa nhanh (InstantWipe)

```
1. Double-click InstantWipe.bat (Run as Admin)
2. Xác nhận 3 lần
3. Máy reboot → Wipe tự động chạy trước login
```

### Cách 2: PowerShell

```powershell
# Thiết lập và reboot để xóa (đợi 10s mặc định)
.\PreOSWipe.ps1 -SetupWipe

# Đợi 30 giây trước khi xóa (có thời gian tắt máy)
.\PreOSWipe.ps1 -SetupWipe -DelaySeconds 30

# Xem danh sách ổ đĩa
.\PreOSWipe.ps1 -ListDisks

# Hủy thiết lập
.\PreOSWipe.ps1 -CancelWipe
```

### Cách 3: Hủy nếu đổi ý

**Trước khi reboot:**
```
- Chạy CancelWipe.bat
- Hoặc: shutdown /a
```

**Sau khi reboot:**
```
- TẮT MÁY trong 10 giây đầu (trước khi wipe bắt đầu)
- Boot từ USB → Xóa Scheduled Task
```

## Quy trình xác nhận

Tool yêu cầu xác nhận 3 lần:
1. Nhập `XOA`
2. Nhập `KHAN CAP`
3. Nhập `TOI DONG Y XOA TAT CA`

## Cảnh báo

```
╔══════════════════════════════════════════════════════════════════╗
║                    !!! CẢNH BÁO TỐI QUAN TRỌNG !!!               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  • Tool này XÓA TẤT CẢ ổ cứng, bao gồm cả ổ Windows (C:)        ║
║  • MBR/GPT bị xóa ngay → Máy KHÔNG THỂ BOOT lại                 ║
║  • Dữ liệu KHÔNG THỂ KHÔI PHỤC bằng bất kỳ phương pháp nào      ║
║  • Cần cài lại Windows hoàn toàn từ USB                         ║
║                                                                  ║
║  CHỈ SỬ DỤNG KHI THỰC SỰ CẦN XÓA KHẨN CẤP!                      ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

## Yêu cầu

- Windows 10/11
- Quyền Administrator
- KHÔNG cần USB boot

## So sánh

| Tính năng | EmergencyWipe (thường) | PreOS Wipe |
|-----------|------------------------|------------|
| Xóa ổ dữ liệu (D:, E:...) | ✅ | ✅ |
| Xóa ổ hệ thống (C:) | ❌ | ✅ |
| Cần USB boot | Không | Không |
| Chạy trước login | Không | ✅ |
| Xóa MBR/GPT | Không | ✅ |

## License

MIT License - Sử dụng miễn phí, tự chịu trách nhiệm.
