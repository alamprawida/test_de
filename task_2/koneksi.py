import sqlite3

conn = sqlite3.connect('database_task_2.db')
conn.close()
print("Database berhasil dibuat!")