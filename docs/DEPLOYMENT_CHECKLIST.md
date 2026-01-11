# Deployment Checklist for Key Cabinet System

## Pre-Installation

### Hardware Verification
- [ ] Windows tablet/PC running Windows 10/11
- [ ] USB hub connected to tablet
- [ ] USB-to-RS485 adapter connected to hub
- [ ] Controller board powered (12V)
- [ ] RS485 wiring: 485A and 485B connected correctly
- [ ] RFID reader connected via USB
- [ ] All key locks connected to controller board

### Software Prerequisites
- [ ] .NET 8.0 SDK installed (for build) OR
- [ ] .NET 8.0 Runtime installed (for published app)
- [ ] SQLite browser (optional, for database management)

## Configuration

### COM Port Setup
- [ ] USB-to-RS485 adapter recognized by Windows
- [ ] COM port number identified (Device Manager)
- [ ] COM port number updated in `appsettings.json`
- [ ] Baud rate confirmed from controller documentation
- [ ] Parity, Data Bits, Stop Bits configured correctly

### RS485 Protocol
- [ ] Controller board documentation reviewed
- [ ] Protocol identified (Modbus RTU, custom, etc.)
- [ ] Command structure understood
- [ ] Test commands verified with serial terminal
- [ ] Slot commands added to `appsettings.json`
- [ ] All slots tested individually
- [ ] Status commands configured (if supported)

### RFID Reader
- [ ] Reader detected by Windows (USB device)
- [ ] Reader mode confirmed (keyboard wedge)
- [ ] Test scan performed in Notepad
- [ ] Card ID format documented
- [ ] Multiple cards tested
- [ ] Read range verified

## Database Setup

### Initial Data
- [ ] Admin password changed from default
- [ ] Test user removed or password changed
- [ ] Real user accounts created
- [ ] RFID cards scanned and IDs recorded
- [ ] RFID IDs assigned to users in database
- [ ] Keys defined in database
- [ ] SlotId values match `appsettings.json` keys
- [ ] User-key permissions assigned
- [ ] Permission matrix verified

### Backup Plan
- [ ] Database backup location chosen
- [ ] Backup script/procedure created
- [ ] Test restore performed
- [ ] Backup schedule established

## Security

### Passwords
- [ ] Default admin password changed
- [ ] All user passwords are strong (12+ characters)
- [ ] Password policy documented
- [ ] Emergency admin account created (optional)

### Remote API (if used)
- [ ] Remote API necessity confirmed
- [ ] Network isolation verified (VPN/internal only)
- [ ] Allowed IP addresses configured
- [ ] Firewall rules created
- [ ] API authentication tested
- [ ] API endpoints documented for users
- [ ] API access monitored

### Physical Security
- [ ] Tablet mounted securely in cabinet
- [ ] USB connections secured/taped
- [ ] Power supply protected
- [ ] Cabinet locked when not in use

## Windows Configuration

### System Settings
- [ ] Sleep mode disabled on AC power
- [ ] Sleep mode disabled on battery
- [ ] Screen timeout extended/disabled
- [ ] Automatic updates scheduled for off-hours
- [ ] Windows Defender configured
- [ ] Unnecessary services disabled

### User Account
- [ ] Dedicated Windows user created (non-admin)
- [ ] Auto-login configured (if desired)
- [ ] User permissions restricted appropriately

### Startup
- [ ] Application shortcut created
- [ ] Shortcut placed in Startup folder
- [ ] Auto-start tested after reboot
- [ ] Error handling on startup verified

### Kiosk Mode (if used)
- [ ] Assigned Access configured
- [ ] Escape keys disabled/restricted
- [ ] Task Manager access restricted
- [ ] Testing performed in kiosk mode

## Testing

### Functional Testing
- [ ] RFID login tested with multiple cards
- [ ] Password login tested
- [ ] Invalid credentials rejection tested
- [ ] Each key slot opens correctly
- [ ] User permissions respected (access denied works)
- [ ] Logout function works
- [ ] Fullscreen mode works
- [ ] Application restarts after crash/close

### Integration Testing
- [ ] All slots tested in sequence
- [ ] Multiple users tested
- [ ] RFID and password login alternating
- [ ] Error conditions handled gracefully
- [ ] Serial port disconnect/reconnect handled
- [ ] RFID reader disconnect handled

### Remote API Testing (if enabled)
- [ ] Health endpoint responds
- [ ] Valid authentication works
- [ ] Invalid authentication rejected
- [ ] Correct slots open
- [ ] Permissions enforced
- [ ] IP filtering works
- [ ] Events logged correctly

### Logging
- [ ] Login events logged
- [ ] Key opening events logged
- [ ] Failed login attempts logged
- [ ] Remote opens logged separately
- [ ] Log viewer accessible
- [ ] Date filtering works
- [ ] CSV export works
- [ ] Export file opens correctly

## Performance

### Response Time
- [ ] RFID scan to login < 2 seconds
- [ ] Key selection to open < 1 second
- [ ] UI remains responsive during operations
- [ ] No lag on touch interactions

### Reliability
- [ ] 24-hour stress test performed
- [ ] Multiple rapid operations tested
- [ ] Memory leaks checked
- [ ] Application doesn't crash under normal use

## Documentation

### User Documentation
- [ ] Simple user guide created (how to scan, how to login)
- [ ] Emergency procedures documented
- [ ] Support contact information posted
- [ ] Quick reference card created

### Technical Documentation
- [ ] Hardware setup documented
- [ ] Configuration files documented
- [ ] Database schema documented
- [ ] API endpoints documented (if used)
- [ ] Troubleshooting guide created

### Maintenance
- [ ] Database backup procedure documented
- [ ] Log cleanup procedure documented
- [ ] User management procedure documented
- [ ] Emergency admin access procedure documented

## Training

### End Users
- [ ] RFID card usage demonstrated
- [ ] Password fallback explained
- [ ] Key selection process shown
- [ ] Logout procedure explained
- [ ] What to do if card doesn't work

### Administrators
- [ ] User account creation
- [ ] Password resets
- [ ] Permission management
- [ ] Log review
- [ ] Basic troubleshooting
- [ ] Database backup/restore

### IT Support
- [ ] Configuration file locations
- [ ] COM port troubleshooting
- [ ] RFID reader issues
- [ ] Database access
- [ ] Application restart/reinstall
- [ ] Remote API configuration (if used)

## Emergency Procedures

### Fallback Plans
- [ ] Manual key access procedure documented
- [ ] Emergency admin login tested
- [ ] Serial port failure workaround
- [ ] RFID reader failure workaround
- [ ] Power failure procedure
- [ ] Network failure procedure (if remote API used)

### Support
- [ ] Support contact information distributed
- [ ] Escalation procedure defined
- [ ] Vendor contacts documented (hardware)
- [ ] 24/7 support plan (if needed)

## Post-Deployment

### Monitoring
- [ ] Daily log review scheduled
- [ ] Weekly backup verification
- [ ] Monthly security audit
- [ ] Quarterly user review (active/inactive)

### Maintenance
- [ ] Windows updates scheduled
- [ ] Application updates planned
- [ ] Database maintenance scheduled
- [ ] Hardware inspection scheduled

### Continuous Improvement
- [ ] User feedback collected
- [ ] Issues tracked
- [ ] Enhancement requests documented
- [ ] Performance metrics recorded

## Sign-Off

### Installation Team
- [ ] Hardware installation complete
- [ ] Software installation complete
- [ ] Configuration verified
- [ ] Testing complete

**Installed by:** _____________________ **Date:** _____________________

### Testing Team
- [ ] All functional tests passed
- [ ] All integration tests passed
- [ ] All users tested
- [ ] All slots tested

**Tested by:** _____________________ **Date:** _____________________

### Operations Team
- [ ] Training received
- [ ] Documentation reviewed
- [ ] Emergency procedures understood
- [ ] Ready for production use

**Accepted by:** _____________________ **Date:** _____________________

---

## Notes / Issues

(Use this space to document any issues found, workarounds applied, or special configuration notes)

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________
