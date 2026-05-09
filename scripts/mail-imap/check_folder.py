import imaplib
import os
from dotenv import load_dotenv

load_dotenv()

mail = imaplib.IMAP4_SSL("imap.mail.me.com")
mail.login(os.getenv("ICLOUD_EMAIL_ADDRESS"), os.getenv("MAIL_APP_PASS"))

status, folders = mail.list()

for f in folders:
    print(f.decode())

mail.logout()
