from dotenv import load_dotenv
import os
import imaplib
import logging
from datetime import datetime, timedelta

load_dotenv()

EMAIL = os.getenv("ICLOUD_EMAIL_ADDRESS")
PASSWORD = os.getenv("MAIL_APP_PASS")
HOST = "imap.mail.me.com"

BATCH_SIZE = 100
RECONNECT_EVERY = 1000  # reconnect after this many emails

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger(__name__)


def connect():
    log.info("Connecting to %s", HOST)
    mail = imaplib.IMAP4_SSL(HOST)
    mail.login(EMAIL, PASSWORD)
    mail.select("INBOX")
    log.info("Connected and INBOX selected")
    return mail


def cleanup_old_emails(days=120):
    mail = connect()

    date = (datetime.now() - timedelta(days=days)).strftime("%d-%b-%Y")
    log.info("Searching emails BEFORE %s", date)

    status, data = mail.uid("SEARCH", None, f"BEFORE {date}")
    if status != "OK":
        log.error("Search failed: status=%s", status)
        mail.logout()
        return

    if not data or not data[0]:
        log.info("No emails found before %s", date)
        mail.logout()
        return

    uids = data[0].split()
    total = len(uids)
    log.info("Found %d emails to delete", total)

    deleted = 0
    for i in range(0, total, BATCH_SIZE):
        batch = uids[i : i + BATCH_SIZE]

        # reconnect periodically to avoid idle/long-session disconnect
        if deleted > 0 and deleted % RECONNECT_EVERY == 0:
            log.info("Reconnecting after %d deletions", deleted)
            try:
                mail.logout()
            except Exception as e:
                log.warning("Logout failed (ignoring): %s", e)
            mail = connect()

        # batch STORE: pass comma-separated UIDs in one command
        uid_set = b",".join(batch)
        status, _ = mail.uid("STORE", uid_set, "+FLAGS", r"(\Deleted)")
        if status != "OK":
            log.error("STORE failed for batch starting at %d", i)
            continue

        # expunge per batch so server load is distributed
        mail.expunge()

        deleted += len(batch)
        log.info(
            "Progress: %d / %d (%.1f%%)",
            deleted,
            total,
            100 * deleted / total,
        )

    log.info("Cleanup done. Deleted %d emails", deleted)
    mail.logout()


if __name__ == "__main__":
    cleanup_old_emails()

