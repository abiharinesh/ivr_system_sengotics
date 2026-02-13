# Deploying to Render

This guide walks you through deploying the IVR System to [Render.com](https://render.com).

## ✨ Why Render?

- **Easy PostgreSQL Setup** - Managed PostgreSQL with PostGIS support
- **Automatic Deployments** - Deploy from GitHub automatically
- **Free Tier Available** - Great for testing (with limitations)
- **Simple Configuration** - Infrastructure as code with `render.yaml`

---

## 📋 Prerequisites

1. **Render Account** - Sign up at [render.com](https://render.com)
2. **GitHub Repository** - Push your code to GitHub
3. **OpenAI API Key** - For AI voice processing features

---

## 🚀 Deployment Steps

### Step 1: Push Code to GitHub

```bash
# Initialize git if not already done
git init
git add .
git commit -m "Initial commit - IVR System"

# Create repository on GitHub, then:
git remote add origin https://github.com/YOUR_USERNAME/ivr-system.git
git branch -M main
git push -u origin main
```

---

### Step 2: Create New Blueprint on Render

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click **"New +"** → **"Blueprint"**
3. Connect your GitHub account if not already connected
4. Select your repository (`ivr-system` or whatever you named it)
5. Click **"Connect"**

Render will automatically detect the `render.yaml` file and show you the services to be created.

---

### Step 3: Review Services

You should see 2 services:

#### 🗄️ Database Service: `ivr-system-db`
- Type: PostgreSQL
- Plan: Starter ($7/month) or Free (limited)
- Database name: `ivr_system`

#### 🌐 Web Service: `ivr-system-api`
- Type: Web Service
- Environment: Node
- Plan: Starter (Free tier available)

Click **"Apply"** to create both services.

---

### Step 4: Configure Environment Variables

After services are created:

1. Navigate to **`ivr-system-api`** service
2. Go to **"Environment"** tab
3. Add the following secret:

| Key | Value |
|-----|-------|
| `OPENAI_API_KEY` | `sk-your-actual-openai-key-here` |

> [!NOTE]
> `DATABASE_URL`, `PORT`, and `NODE_ENV` are already configured in `render.yaml`.

Click **"Save Changes"**. This will trigger a redeploy.

---

### Step 5: Enable PostGIS Extension

The PostGIS extension is required for geospatial features.

1. Go to **`ivr-system-db`** database service
2. Click **"Shell"** tab to open database shell
3. Run the following SQL command:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

4. Verify installation:

```sql
SELECT PostGIS_Version();
```

You should see the PostGIS version number.

> [!TIP]
> Alternatively, PostGIS is already specified in `schema.prisma` and should be created automatically by Prisma migrations.

---

### Step 6: Wait for Deployment

1. Go to **`ivr-system-api`** service
2. Click **"Logs"** tab
3. Wait for deployment to complete

You should see:
```
==> Running 'npx prisma migrate deploy'
✓ Migrations applied successfully

==> Running 'npm run start:prod'
[Nest] INFO  NestJS application successfully started on http://localhost:3000
```

---

### Step 7: Get Your Service URL

1. In the **`ivr-system-api`** service dashboard
2. Copy the URL shown at the top (e.g., `https://ivr-system-api.onrender.com`)

This is your production URL! 🎉

---

## ✅ Verify Deployment

### Test Health Endpoint

```bash
curl https://YOUR-SERVICE-NAME.onrender.com/
```

Expected: Should return a response (200 OK)

### Test IVR Endpoint

```bash
curl -X POST https://YOUR-SERVICE-NAME.onrender.com/api/ivr/service \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "CallSid=test001&CallFrom=9876543210&CallTo=1234567890&digits=1&flow_id=test&tenant_id=test1"
```

Expected: `{}` with HTTP 200

### Check Database

1. Go to Render dashboard → `ivr-system-db`
2. Click **"Shell"** tab
3. Run:

```sql
\dt
```

You should see all your tables:
- `calls_master`
- `ivr_service_selection`
- `ivr_poll_input`
- `ivr_voicemail`
- `panchayats`
- `electric_poles`
- `complaints`
- `voice_calls`

---

## 🔧 Configure Exotel Webhooks

Now that your service is live, configure Exotel to send callbacks to your Render URL:

1. Log in to [Exotel Dashboard](https://my.exotel.com)
2. Go to your IVR flow configuration
3. Set webhook URLs:

| Event | Webhook URL |
|-------|-------------|
| Service Selection | `https://YOUR-SERVICE.onrender.com/api/ivr/service` |
| Poll Input | `https://YOUR-SERVICE.onrender.com/api/ivr/poll` |
| Voicemail | `https://YOUR-SERVICE.onrender.com/api/ivr/voicemail` |

4. Set method to **POST**
5. Save configuration

---

## 🔁 Automatic Deployments

Every time you push to your `main` branch on GitHub, Render will automatically:

1. Pull the latest code
2. Run build command
3. Run database migrations
4. Restart the service

To disable auto-deploy:
1. Go to service settings
2. Toggle **"Auto-Deploy"** off

---

## 📊 Monitoring & Logs

### View Logs

1. Go to your service in Render dashboard
2. Click **"Logs"** tab
3. See real-time application logs

### Metrics

1. Click **"Metrics"** tab
2. View:
   - CPU usage
   - Memory usage
   - Response times
   - HTTP requests

---

## 🐛 Troubleshooting

### Issue: Build Fails

**Symptoms**: Deployment fails during build step

**Solution**:
```bash
# Check if it builds locally first
npm install
npm run build

# If successful, commit any missing files
git add .
git commit -m "Fix build issues"
git push
```

---

### Issue: Database Connection Error

**Symptoms**: Logs show "Can't reach database server"

**Solution**:
1. Verify `DATABASE_URL` is set correctly
2. Check database service is running
3. Verify database and web service are in the same region

---

### Issue: PostGIS Not Found

**Symptoms**: Migration fails with "extension 'postgis' does not exist"

**Solution**:
```sql
-- In database shell:
CREATE EXTENSION IF NOT EXISTS postgis;

-- Then trigger redeploy of web service
```

---

### Issue: OpenAI API Errors

**Symptoms**: Voice processing fails

**Solution**:
1. Verify `OPENAI_API_KEY` is set in environment variables
2. Check the key is valid
3. Verify you have API credits

---

### Issue: Migrations Don't Run

**Symptoms**: Tables don't exist in database

**Solution**:
1. Check build logs for migration errors
2. Manually run migrations in database shell:
   ```bash
   # Or run migrations manually via Render shell
   npx prisma migrate deploy
   ```

---

## 💰 Pricing

### Free Tier
- **Web Service**: 750 hours/month free
- **Database**: Not available on free tier (must use external DB or upgrade)

### Starter Plan (Recommended)
- **Web Service**: $7/month
- **Database (PostgreSQL)**: $7/month
- **Total**: ~$14/month

### Resources
- 512 MB RAM
- Shared CPU
- Suitable for development and small-scale production

For pricing details: [render.com/pricing](https://render.com/pricing)

---

## 🔐 Security Best Practices

1. **Never commit `.env` files** - Already in `.gitignore`
2. **Use environment variables** for all secrets
3. **Enable IP allowlisting** for database if needed
4. **Use HTTPS** - Render provides this automatically
5. **Rotate API keys** regularly

---

## 🔄 Database Backup

Render automatically backs up PostgreSQL databases:
- Daily backups for 7 days (Free/Starter)
- Point-in-time recovery (Pro plan)

To download a backup:
1. Go to database service
2. Click **"Backups"** tab
3. Download latest backup

---

## 📝 Seeding the Database

To seed your production database with dummy data:

1. Connect to the database shell on Render
2. Or use a local connection string:

```bash
# Set DATABASE_URL to your Render database
export DATABASE_URL="postgresql://..."

# Run seed script
npm run seed
```

> [!WARNING]
> Only seed development databases. Don't seed production with dummy data!

---

## 🎯 Next Steps

After successful deployment:

1. ✅ Test all IVR endpoints with real Exotel calls
2. ✅ Monitor logs for any errors
3. ✅ Set up admin dashboard (if needed)
4. ✅ Configure database backups
5. ✅ Set up monitoring alerts

---

## 📚 Additional Resources

- [Render Documentation](https://render.com/docs)
- [NestJS Deployment Guide](https://docs.nestjs.com/deployment)
- [Prisma in Production](https://www.prisma.io/docs/guides/deployment/deployment-guides)
- [PostgreSQL on Render](https://render.com/docs/databases)

---

## 🆘 Need Help?

- Check Render [Community Forum](https://community.render.com)
- Review application logs in Render dashboard
- Check database connectivity
- Verify environment variables are set correctly

---

**Happy Deploying! 🚀**
