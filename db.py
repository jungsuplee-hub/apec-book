import os
import MySQLdb
from contextlib import contextmanager


MYSQL_HOST=os.getenv('MYSQL_HOST','127.0.0.1')
MYSQL_PORT=int(os.getenv('MYSQL_PORT','3306'))
MYSQL_DB=os.getenv('MYSQL_DB','apec_booking')
MYSQL_USER=os.getenv('MYSQL_USER','apec')
MYSQL_PASSWORD=os.getenv('MYSQL_PASSWORD','strong-password')


@contextmanager
def get_conn():
conn = MySQLdb.connect(
host=MYSQL_HOST, port=MYSQL_PORT, db=MYSQL_DB,
user=MYSQL_USER, passwd=MYSQL_PASSWORD,
charset='utf8mb4', autocommit=False
)
try:
yield conn
conn.commit()
except:
conn.rollback()
raise
finally:
conn.close()
