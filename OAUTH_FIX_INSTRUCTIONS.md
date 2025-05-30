# OAuth & Database Fix Instructions for EC2

## 🚀 Quick Fix for Production Issues

### Issues Fixed:
1. **Database Authentication Error**: `password authentication failed for user "focuspad_user"`
2. **OAuth Callback Loop**: Redirecting to login after successful Google authentication
3. **HTTP vs HTTPS Redirect URI**: OAuth using HTTP instead of HTTPS
4. **Flask Configuration**: Missing BASE_URL configuration

---

## 📋 **Steps to Execute on EC2**

### 1. **SSH into your EC2 instance**
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 2. **Navigate to your FocusPad directory**
```bash
cd /path/to/focuspad  # Replace with your actual path
```

### 3. **Copy and run the fix script**

**Option A: Download the script directly**
```bash
# Download the fix script
wget https://raw.githubusercontent.com/yourusername/focuspad/main/fix-oauth-production.sh

# Make it executable
chmod +x fix-oauth-production.sh

# Run the fix
./fix-oauth-production.sh
```

**Option B: Create the script manually**
```bash
# Create the script file
nano fix-oauth-production.sh

# Copy the entire script content from fix-oauth-production.sh
# Save and exit (Ctrl+X, then Y, then Enter)

# Make it executable
chmod +x fix-oauth-production.sh

# Run the fix
./fix-oauth-production.sh
```

---

## 🔧 **What the Script Does**

1. **Creates backups** of current files
2. **Updates OAuth redirect URI** to force HTTPS for thefocuspad.com
3. **Fixes Flask configuration** with proper BASE_URL handling
4. **Cleans database volumes** to resolve authentication issues
5. **Rebuilds containers** with fresh configuration
6. **Tests the deployment** and provides status

---

## ⚙️ **Google Cloud Console Settings Required**

After running the script, verify these settings in your Google Cloud Console:

### OAuth 2.0 Client IDs Configuration:
- **Authorized JavaScript origins**: `https://thefocuspad.com`
- **Authorized redirect URIs**: `https://thefocuspad.com/auth/callback/google`

### Steps to update:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Navigate to: APIs & Services → Credentials
4. Click on your OAuth 2.0 Client ID
5. Update the settings as shown above
6. Save changes

---

## 🧪 **Testing the Fix**

After running the script:

1. **Check containers are running**:
   ```bash
   docker-compose -f docker-compose.micro.yml --env-file .env.production ps
   ```

2. **Test health endpoint**:
   ```bash
   curl http://localhost/health
   ```

3. **Test OAuth flow**:
   - Go to: `https://thefocuspad.com`
   - Click "Sign in with Google"
   - Complete authentication
   - Should redirect to dashboard (not login loop)

---

## 🔍 **Troubleshooting Commands**

If issues persist after running the script:

```bash
# View detailed logs
docker-compose -f docker-compose.micro.yml --env-file .env.production logs -f web

# Check container status
docker-compose -f docker-compose.micro.yml --env-file .env.production ps

# Restart containers
docker-compose -f docker-compose.micro.yml --env-file .env.production restart

# Test health endpoint
curl http://localhost/health

# Test with detailed output
curl -v https://thefocuspad.com/health
```

---

## 📝 **Environment Variables Check**

Ensure these are properly set in `.env.production`:

```bash
# Check if environment variables are set correctly
grep -E "(BASE_URL|GOOGLE_CLIENT)" .env.production
```

Required variables:
- `BASE_URL=https://thefocuspad.com`
- `GOOGLE_CLIENT_ID=your-actual-client-id`
- `GOOGLE_CLIENT_SECRET=your-actual-client-secret`

---

## 🎯 **Expected Results**

After successful fix:
- ✅ No database authentication errors
- ✅ OAuth redirects to dashboard after login
- ✅ HTTPS redirect URIs working correctly
- ✅ Sessions maintained properly
- ✅ Health endpoint returns `{"status": "healthy"}`

---

## 🚨 **If Script Fails**

1. **Check Docker is running**:
   ```bash
   sudo systemctl status docker
   ```

2. **Check disk space**:
   ```bash
   df -h
   ```

3. **Manually restart Docker**:
   ```bash
   sudo systemctl restart docker
   ```

4. **Re-run the script**:
   ```bash
   ./fix-oauth-production.sh
   ```

---

## 📞 **Support**

If you encounter issues:
1. Check the troubleshooting commands above
2. Review container logs for specific errors
3. Verify Google Cloud Console OAuth settings
4. Ensure `.env.production` has correct values 