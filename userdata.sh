#!/bin/bash

rds_host=$1
rds_username=$2
rds_password=$3
rds_name=$4
s3_name=$5
strapi_domain=$6
aws_access_key=$7
aws_secret_key=$8
aws_region=$9

# Update package manager cache
sudo apt update

cd ~
touch testfile
echo $rds_host >> testfile
echo $rds_username >> testfile
echo $rds_password >> testfile
echo $rds_name >> testfile
echo $s3_name >> testfile
echo $strapi_domain >> testfile
echo $(whoami) >> testfile

# Install dependencies
sudo apt install net-tools -y
sudo apt install -y curl git

# Update package lists
sudo apt-get update

# Create new database and user
#domain=${strapi_domain}
#dbhost=${rds_host}
#database=${rds_name}
#user=${rds_username}
#password=${rds_password}


# Display database and user information
echo "Database: ${rds_name}"
echo "User: ${rds_username}"
echo "Password: ${rds_password}"

# Install Node.js
curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt install -y nodejs

# Install Yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update
sudo apt install -y yarn

cd ~

# Install Strapi
echo "current directory is $(pwd) for creating my-project" >> testfile
echo "1" | timeout 240 npx create-strapi-app my-project
echo "Background process completed"

ls -la
pwd >> testfile

#Installing pg client
npm install pg
cd ~/my-project/

#Creating database connection file
sudo cat <<EOT > config/database.js
// path: ./my-project/config/database.js

module.exports = ({ env }) => ({
  connection: {
    client: "postgres",
    connection: {
      host: env("DATABASE_HOST", ""),
      port: env.int("DATABASE_PORT", 5432),
      database: env("DATABASE_NAME", "${rds_name}"),
      user: env("DATABASE_USERNAME", "${rds_username}"),
      password: env("DATABASE_PASSWORD", "${rds_password}"),
    },
    useNullAsDefault: true,
  },
}
);
EOT

#Installing S3 provider
npm install @strapi/provider-upload-aws-s3

#Creating file for AWS S3
sudo cat <<EOT > config/plugins.js
module.exports = ({ env }) => ({
  upload: {
    config: {
      provider: 'aws-s3',
      providerOptions: {
        accessKeyId: env('${aws_access_key}'),
        secretAccessKey: env('${aws_secret_key}'),
        region: env('${aws_region}'),
        params: {
            Bucket: env('${s3_name}'),
        },
      },
      // These parameters could solve issues with ACL public-read access — see [this issue](https://github.com/strapi/strapi/issues/5868) for details
      actionOptions: {
        upload: {
          ACL: null
        },
        uploadStream: {
          ACL: null
        },
      }
    },
  }
}
);
EOT

#starting the project in dev environment 
echo "Now current directory is $(pwd) for npm run" >> testfile
NODE_ENV=production npm run build

# Install PM2
cd ~
echo "Now current directory is $(pwd) for pm2" >> testfile
sudo npm install pm2@latest -g

#creating npm file to start the project
sudo cat <<EOT >> ecosystem.config.js
    module.exports = {
    apps: [
        {
        name: 'strapi', // Your project name
        cwd: '/home/ubuntu/my-project', // Path to your project
        script: 'npm', // For this example we're using npm, could also be yarn
        args: 'start', // Script to start the Strapi server, `start` by default
        env: {
            NODE_ENV: 'production',
            DATABASE_HOST: '${rds_host}', // database Endpoint under 'Connectivity & Security' tab
            DATABASE_PORT: '5432',
            DATABASE_NAME: '${rds_name}', // DB name under 'Configuration' tab
            DATABASE_USERNAME: '${rds_username}', // default username
            DATABASE_PASSWORD: '${rds_password}',
        },
        },
    ],
    };
EOT

cd ~
echo "Now current directory is $(pwd) for pm2 start" >> testfile
pm2 start ecosystem.config.js

#creating systemd service of pm2
sysoutput=$(pm2 startup systemd | sed -n '1,2!p')
$sysoutput
pm2 save


# Generate a strong DH parameter file (takes a long time!)
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 1024

# Install Nginx
echo "Now current directory is $(pwd) for nginx" >> testfile
sudo apt install -y nginx

# Create an Nginx configuration file for Strapi
sudo bash -c 'cat > /etc/nginx/sites-available/my-project <<EOF
    server {
        listen 80;
        listen [::]:80;
        server_name '${strapi_domain}';
        error_log /var/log/nginx/strapi-error.log;
        access_log /var/log/nginx/strapi-access.log;

        location / {
            proxy_pass http://localhost:1337;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }
EOF'

# Enable the Nginx configuration
sudo ln -s /etc/nginx/sites-available/my-project /etc/nginx/sites-enabled/

# Remove the default Nginx configuration
sudo rm /etc/nginx/sites-enabled/default

# Test the Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

#setting up env file
cat <<EOT >> /home/ubuntu/my-project/.env
DATABASE_HOST=${rds_host}
DATABASE_PORT=5432
DATABASE_NAME=${rds_name}
DATABASE_USERNAME=${rds_username}
DATABASE_PASSWORD=${rds_password}
EOT

#pkill -f strapi
setsid pkill strapi
echo $(whoami) >> testfile
echo "Success!!"