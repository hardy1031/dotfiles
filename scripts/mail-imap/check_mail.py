import os
import imaplib
from dotenv import load_dotenv

load_dotenv()

EMAIL = os.getenv("ICLOUD_EMAIL_ADDRESS")
PASSWORD = os.getenv("MAIL_APP_PASS")

HOST = "imap.mail.me.com"


# ======================
# connect
# ======================
mail = imaplib.IMAP4_SSL(HOST)
mail.login(EMAIL, PASSWORD)


# ======================
# helper: safe select
# ======================
def safe_select(mail, keyword):
    status, folders = mail.list()

    if status != "OK":
        print("list failed")
        return None

    for f in folders:
        line = f.decode()

        if keyword in line:
            # IMAPの右側（そのまま）
            parts = line.split(' "/" ')
            folder = parts[-1].strip()

            # クォート除去だけ（最小限）
            if folder.startswith('"') and folder.endswith('"'):
                folder = folder[1:-1]

            status, _ = mail.select(f'"{folder}"')

            if status == "OK":
                return folder

    print("not found")
    return None

# ======================
# counter
# ======================
def count_mail(mail, folder, label):
    status, _ = mail.select(folder)

    if status != "OK":
        print(f"{label}: cannot select ({folder})")
        return

    status, data = mail.search(None, "ALL")

    if status != "OK":
        print(f"{label}: search failed")
        return

    count = len(data[0].split())
    print(f"{label}: {count}")


# ======================
# INBOX
# ======================
count_mail(mail, "INBOX", "INBOX")


# ======================
# Trash (iCloud safe resolve)
# ======================
trash_folder = safe_select(mail, "Deleted Messages")

if trash_folder:
    status, data = mail.search(None, "ALL")

    if status == "OK":
        print(f"Trash: {len(data[0].split())}")
else:
    print("Trash: not found")


# ======================
# ALL (server view)
# ======================
mail.select("INBOX")
status, data = mail.search(None, "ALL")
print(f"ALL (INBOX view): {len(data[0].split())}")


# ======================
# cleanup
# ======================
mail.logout()
