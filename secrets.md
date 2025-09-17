
### **Secrets Management Protocol for the Solo Operator**

This protocol has two parts: **Storage (Where secrets live)** and **Usage (How we access them)**.

### **Part 1: Centralized & Secure Storage**

From now on, all secrets will be stored in a single, dedicated, and secured directory on the host.

**Step 1: Create a Central Secrets Directory**
We will create a master secrets directory outside of the `/srv` tree to keep it separate from application code and data. `/opt/secrets` is a common and appropriate choice.

```bash
sudo mkdir -p /opt/secrets
```

**Step 2: Set Strict Permissions**
This is the most important step. We will lock this directory down so that only the `root` user can access its contents. Your `opc` user will need to use `sudo` to read or write secrets, which provides an audit trail and forces intentionality.

```bash
# Set ownership to root
sudo chown -R root:root /opt/secrets

# Set permissions:
# Owner (root): read, write, execute
# Group: none
# Others: none
sudo chmod -R 700 /opt/secrets
```

**Step 3: Consolidate All Existing Secrets**
We will now move all the password files we've created into this central vault and ensure their paths are updated in the `docker-compose.yml` files.

```bash
# Move the Trading App password
sudo mv /srv/config/trading-app/trading_app_password.txt /opt/secrets/trading_app_db_password.txt

# Move the Librarian App password
sudo mv /srv/config/librarian-app/librarian_app_password.txt /opt/secrets/librarian_app_db_password.txt

# Move the Librarian API key
sudo mv /srv/config/librarian-app/librarian_api_key.txt /opt/secrets/librarian_api_key.txt

# Clean up the old, now-empty directories
sudo rmdir /srv/config/trading-app
sudo rmdir /srv/config/librarian-app
```

**Step 4: Update Docker Compose Files**
Now, we must update our `docker-compose.yml` files to point to the new, canonical location of these secrets.

1.  **Edit `/srv/apps/trading-app/docker-compose.yml`:**
    *   Find the top-level `secrets:` block.
    *   Change `file: /srv/config/trading-app/trading_app_password.txt` to `file: /opt/secrets/trading_app_db_password.txt`.

2.  **Edit `/srv/apps/librarian-app/docker-compose.yml`:**
    *   Find the top-level `secrets:` block.
    *   Change `file: /srv/config/librarian-app/librarian_api_key.txt` to `file: /opt/secrets/librarian_api_key.txt`.
    *   *(Note: The librarian's DB password is in its `server.env`, which we'll address next).*

**Step 5: Re-deploy Services to Use New Secret Paths**
```bash
cd /srv/apps/trading-app && sudo docker compose up -d
cd /srv/apps/librarian-app && sudo docker compose up -d
```

### **Part 2: Usage and Maintenance**

Now you have a single, secure place to manage all secrets.

**How to View a Password:**
You can no longer just `cat` the file. You must explicitly use `sudo`.
```bash
# Example: View the trading app's DB password
sudo cat /opt/secrets/trading_app_db_password.txt
```

**How to Generate and Store a New Password:**
Follow this pattern for any new secret you need to create.
```bash
# 1. Generate the secret
NEW_SECRET=$(openssl rand -base64 32)

# 2. Store it directly in the central vault with the correct permissions
echo -n "$NEW_SECRET" | sudo tee /opt/secrets/new_service_api_key.txt > /dev/null

# 3. (Optional) Display it once to copy it elsewhere if needed
echo "The new secret is: $NEW_SECRET"
```

**How to Handle Environment Variables (The `.env` files):**
Your `server.env` files for the applications still contain passwords. This is not ideal. The best practice is to have the application itself read the password from a file path specified by an environment variable, just like the Trading App does.

*   **The Good Pattern (Trading App):**
    *   `docker-compose.yml`: Uses `secrets:` to mount the file.
    *   `environment:` sets `POSTGRES_PASSWORD_FILE=/run/secrets/db_password`.
    *   The application code opens and reads this file.

*   **The "To Be Improved" Pattern (Librarian App):**
    *   `server.env`: Contains `DATABASE_URL="...${LIBRARIAN_APP_PASSWORD}..."`.
    *   **Future Technical Debt:** The Librarian app should be refactored to read its database password from a file path, just like the Trading App. For now, you must manually manage the password in its `server.env` file.

### **Your New "Password Cheat Sheet"**

You no longer need to remember passwords. You only need to remember **one command** to see all your secrets:

```bash
sudo ls -1 /opt/secrets
```

This will list the filenames of all your secrets. From there, you can `sudo cat` the specific one you need. This is your new, secure workflow.