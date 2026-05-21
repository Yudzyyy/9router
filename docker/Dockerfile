# Lightweight 9Router from npm package
FROM node:20-alpine

WORKDIR /app

# Install dumb-init and curl
RUN apk add --no-cache dumb-init curl

# Install 9Router globally
RUN npm install -g 9router@latest

# Create directories for logs and config
RUN mkdir -p /app/logs /app/config

# Expose port
EXPOSE 20128

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:20128/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start server directly with node
CMD ["node", "/usr/local/lib/node_modules/9router/app/server.js"]
