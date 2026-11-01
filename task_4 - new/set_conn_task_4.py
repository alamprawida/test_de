import sqlite3
import pandas as pd

conn = sqlite3.connect('db_task_4.db')
print("berhasil dibuat!")


df = pd.read_csv('ArifReport.csv')
df.to_sql('report_arif', conn, if_exists='replace', index=False)

conn.commit()
conn.close()

print("CSV diimpor!")