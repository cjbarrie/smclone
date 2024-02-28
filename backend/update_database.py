import sqlite3

# Connect to the database
conn = sqlite3.connect('users.db')
c = conn.cursor()

# Drop the old users table
c.execute('DROP TABLE IF EXISTS users')

# Create a new users table with the updated structure
c.execute('''
    CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        uuid TEXT
    )
''')

# Commit the changes and close the connection
conn.commit()
conn.close()

