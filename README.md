# MySQL Remote Host CSF Whitelister

A secure and performance-optimized shell script that automatically syncs MySQL remote host IPs with the CSF firewall on cPanel/WHM servers.

This script fetches all non-local MySQL user host IPs and hostnames that are added to cPanel MySQL Remote Host, excludes the server's own IPs and hostnames, and whitelists them using CSF—ensuring seamless remote MySQL access without manual firewall entries and edits. The script, with cronjob, automatically adds new IP addresses to CSF (ConfigServer Firewall) when a cPanel user adds them to their cPanel MySQL Remote Host. It's super easy and time-saving!

---

## 🔧 Features

- ✅ Fully automated CSF whitelisting for remote MySQL hosts
- 🚫 Skips localhost, private ranges, and server-owned IPs
- 🛠 Efficient (non-looping), clean, and secure execution
- 📄 Dry-run mode for safe validation
- 📝 Logs all actions and warnings/errors separately

---

## 📥 Installation

`
wget https://raw.githubusercontent.com/thekugelblitz/MySQL-Remote-Host-CSF-Whitelister/main/mysql_csf_whitelist.sh
chmod +x /root/mysql_csf_whitelist.sh
`

---

## ⏱ Cron Setup

Run the script automatically every 1 minute or as per your need, like 15 minutes:

`* * * * * /bin/bash /root/mysql_csf_whitelist.sh >> /var/log/mysql_csf_cron.log 2>&1`

For debugging/testing:

`*/1 * * * * /bin/bash /root/mysql_csf_whitelist.sh --dry-run >> /var/log/mysql_csf_cron_test.log 2>&1`

---

## ⚙️ Usage

### ➤ Run Manually

`
./mysql_csf_whitelist.sh
`

### ➤ Dry Run

`
./mysql_csf_whitelist.sh --dry-run
`

This will show all the IPs it would whitelist without making any changes.

---

## 📂 Logs

- ✅ Main Log: /var/log/mysql_csf_cron.log
- ⚠️ Error/Skip Log: /var/log/mysql_csf_whitelist_error.log

---

## 🔐 Requirements

- Root access
- CSF (ConfigServer Security & Firewall) installed
- cPanel/WHM with MySQL enabled

---

## 🧑‍💻 Example MySQL Output Handled

CSF Output:

`
csf.allow: 45.11.XX.XX # Auto-whitelist:mysql:2025-04-08 - Tue Apr  8 03:21:20 2025
`

Default MySQL fetch query:

```
mysql> SELECT Host, User FROM mysql.user WHERE Host NOT IN ('localhost', '127.0.0.1', '::1');
+--------------+--------------------+
| Host         | User               |
+--------------+--------------------+
| 103.99.XX.XX | example_remote     |
| 192.168.1.10 | bad_entry          |
| server.host  | should_be_skipped  |
| 45.11.XX.XX  | good_ip            |
+--------------+--------------------+
```

This script will **only allow valid public IPs or hostnames**, not local/private ones.


---

## **🤝 Contribution**
Developed by **Dhruval Joshi** from **[HostingSpell](https://hostingspell.com)**  
GitHub Profile: [@thekugelblitz](https://github.com/thekugelblitz)

If you want to contribute, feel free to fork and submit a PR! 🚀

---

## **📜 License**
This script is released under the **GNU GENERAL PUBLIC LICENSE Version 3**. You are free to modify and use it for commercial or personal use. I would appreciate your contribution! 😊

---
