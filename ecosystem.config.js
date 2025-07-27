module.exports = {
  apps: [
    {
      name: 'recloop-frontend',
      script: 'npm',
      args: 'run preview',
      cwd: './frontend',
      env: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      log_file: '/var/log/pm2/recloop-frontend.log',
      error_file: '/var/log/pm2/recloop-frontend-error.log',
      out_file: '/var/log/pm2/recloop-frontend-out.log'
    },
    {
      name: 'recloop-backend',
      script: 'npm',
      args: 'run start',
      cwd: './backend',
      env: {
        NODE_ENV: 'production'
      },
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      log_file: '/var/log/pm2/recloop-backend.log',
      error_file: '/var/log/pm2/recloop-backend-error.log',
      out_file: '/var/log/pm2/recloop-backend-out.log'
    },
    {
      name: 'recloop-webhook',
      script: 'npm',
      args: 'run start',
      cwd: './webhook-server',
      env: {
        NODE_ENV: 'production',
        PORT: 3001
      },
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      log_file: '/var/log/pm2/recloop-webhook.log',
      error_file: '/var/log/pm2/recloop-webhook-error.log',
      out_file: '/var/log/pm2/recloop-webhook-out.log'
    }
  ]
};