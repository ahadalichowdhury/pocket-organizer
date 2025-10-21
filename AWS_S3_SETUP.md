# AWS S3 Storage Setup Guide

## Why AWS S3 Instead of Firebase Storage?

✅ **Better Performance** - Faster uploads/downloads globally  
✅ **More Reliable** - 99.999999999% (11 9's) durability  
✅ **Cheaper** - Pay only for what you use, free tier available  
✅ **More Flexible** - Works with DigitalOcean Spaces, Wasabi, Backblaze B2, etc.  
✅ **No Firebase Lock-in** - Industry standard S3 API

---

## Quick Setup (3 Options)

### Option 1: AWS S3 (Recommended - Free Tier Available)

#### Step 1: Create AWS Account

1. Go to [aws.amazon.com](https://aws.amazon.com/)
2. Click "Create an AWS Account"
3. Follow the signup process (requires credit card, but free tier is generous)

#### Step 2: Create S3 Bucket

1. Go to [S3 Console](https://s3.console.aws.amazon.com/s3/)
2. Click **"Create bucket"**
3. **Bucket name**: `pocket-organizer` (or your custom name)
4. **Region**: Choose closest to your users (e.g., `us-east-1`)
5. **Block all public access**: UNCHECK this (we need public read access for images)
6. Scroll down and click **"Create bucket"**

#### Step 3: Configure Bucket for Public Read

1. Click on your bucket name
2. Go to **Permissions** tab
3. Scroll to **Bucket policy**
4. Click **Edit** and paste this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::pocket-organizer/*"
    }
  ]
}
```

**⚠️ Important**: Replace `pocket-organizer` with your bucket name!

5. Click **Save changes**

#### Step 4: Create IAM User & Get Access Keys

1. Go to [IAM Console](https://console.aws.amazon.com/iam/)
2. Click **Users** → **Create user**
3. **User name**: `pocket-organizer-app`
4. Click **Next**
5. **Set permissions**: Click "Attach policies directly"
6. Search for and select: `AmazonS3FullAccess`
7. Click **Next** → **Create user**
8. Click on the username you just created
9. Go to **Security credentials** tab
10. Scroll to **Access keys** → Click **"Create access key"**
11. Choose **"Application running outside AWS"**
12. Click **Next** → **Create access key**
13. **SAVE THESE NOW** (you won't see them again):
    - Access key ID (looks like: `AKIAIOSFODNN7EXAMPLE`)
    - Secret access key (looks like: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`)

#### Step 5: Update .env File

Add these to your `.env` file:

```env
# AWS S3 Configuration
AWS_S3_BUCKET=pocket-organizer
AWS_ACCESS_KEY_ID=your_access_key_id_here
AWS_SECRET_ACCESS_KEY=your_secret_access_key_here
AWS_S3_REGION=us-east-1
AWS_S3_ENDPOINT=s3.amazonaws.com
AWS_S3_USE_SSL=true
```

#### Step 6: Test It!

1. Restart your app
2. Add a new document with an image
3. Check console logs - you should see:

```
✅ [S3] Initialized successfully
📤 [S3] Uploading image: image.jpg
   Upload progress: 100%
✅ [S3] Upload successful
   Public URL: https://pocket-organizer.s3.us-east-1.amazonaws.com/users/.../image.jpg
```

---

### Option 2: DigitalOcean Spaces (Cheaper, Simpler)

DigitalOcean Spaces is S3-compatible and costs just **$5/month** for 250GB storage + 1TB bandwidth!

#### Setup:

1. Create account at [digitalocean.com](https://digitalocean.com/)
2. Go to **Spaces** → **Create Space**
3. Choose datacenter region
4. Name your space: `pocket-organizer`
5. **CDN**: Enable it (faster downloads)
6. Go to **API** → **Spaces Keys**
7. Click **Generate New Key**
8. Save the **Access Key** and **Secret Key**

#### .env Configuration:

```env
AWS_S3_BUCKET=pocket-organizer
AWS_ACCESS_KEY_ID=your_spaces_key_id
AWS_SECRET_ACCESS_KEY=your_spaces_secret_key
AWS_S3_REGION=nyc3
AWS_S3_ENDPOINT=nyc3.digitaloceanspaces.com
AWS_S3_USE_SSL=true
```

---

### Option 3: Wasabi (Best Price for Large Storage)

Wasabi is 80% cheaper than AWS S3! No egress fees.

#### Setup:

1. Create account at [wasabi.com](https://wasabi.com/)
2. Click **Buckets** → **Create Bucket**
3. Name: `pocket-organizer`
4. Region: Choose closest to you
5. Go to **Access Keys** → **Create New Access Key**
6. Save the keys

#### .env Configuration:

```env
AWS_S3_BUCKET=pocket-organizer
AWS_ACCESS_KEY_ID=your_wasabi_access_key
AWS_SECRET_ACCESS_KEY=your_wasabi_secret_key
AWS_S3_REGION=us-east-1
AWS_S3_ENDPOINT=s3.wasabisys.com
AWS_S3_USE_SSL=true
```

---

## Pricing Comparison

| Service              | Storage    | Transfer     | Cost/Month (for 10GB + 50GB transfer)          |
| -------------------- | ---------- | ------------ | ---------------------------------------------- |
| **AWS S3**           | $0.023/GB  | $0.09/GB     | ~$4.70 (Free tier: 5GB storage, 15GB transfer) |
| **DigitalOcean**     | Fixed $5   | 1TB included | $5.00 (Best for predictable usage)             |
| **Wasabi**           | $0.0059/GB | FREE         | $0.06 (Best for large files)                   |
| **Firebase Storage** | $0.026/GB  | $0.12/GB     | $6.26 (Most expensive!)                        |

---

## Testing Your Setup

After configuration, you can verify it's working:

1. **Console Logs** (when adding document):

```
✅ [S3] Initialized successfully
   Endpoint: s3.amazonaws.com
   Region: us-east-1
📤 [S3] Uploading image: document.jpg
   File size: 1234567 bytes
   Upload progress: 100%
✅ [S3] Upload successful
```

2. **MongoDB** (check `cloudImageUrl`):

```json
{
  "_id": "abc-123",
  "localImagePath": "/data/user/.../image.jpg",
  "cloudImageUrl": "https://pocket-organizer.s3.us-east-1.amazonaws.com/users/xyz/documents/abc-123/image.jpg"
}
```

3. **Access the URL** - Open the `cloudImageUrl` in browser, image should display!

---

## Troubleshooting

### Error: `NoSuchBucket`

- **Cause**: Bucket name in .env doesn't match actual bucket
- **Fix**: Double-check `AWS_S3_BUCKET` value

### Error: `InvalidAccessKeyId`

- **Cause**: Access key is wrong
- **Fix**: Regenerate keys in AWS Console

### Error: `SignatureDoesNotMatch`

- **Cause**: Secret key is incorrect
- **Fix**: Check for typos, regenerate if needed

### Error: `AccessDenied`

- **Cause**: Bucket policy doesn't allow public read
- **Fix**: Apply the bucket policy from Step 3 above

### Images Not Showing

- **Cause**: Bucket is private
- **Fix**: Make bucket publicly readable (see bucket policy above)

---

## Security Notes

✅ **Access Keys**:

- Never commit them to git
- Store only in `.env` (which is in `.gitignore`)
- Rotate keys periodically

✅ **Bucket Policy**:

- Allows public READ only (viewing images)
- Uploads require authentication (your access keys)
- Users can only upload to their own folder

✅ **User Data Isolation**:

- Images stored in: `users/{userId}/documents/{documentId}/`
- Each user can only access their own images

---

## Need Help?

- AWS S3 Docs: https://docs.aws.amazon.com/s3/
- DigitalOcean Spaces: https://docs.digitalocean.com/products/spaces/
- Wasabi: https://wasabi-support.zendesk.com/

**The app works fine without cloud storage - images are saved locally!**
