# Base stage
FROM node:20-alpine AS base

# Development stage
FROM base AS development
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./
COPY prisma ./prisma/
COPY prisma.config.ts ./

# Install dependencies
RUN npm install

# Generate Prisma Client
RUN npx prisma generate

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

CMD ["npm", "run", "start:dev"]

# Build stage
FROM development AS build
WORKDIR /usr/src/app

RUN npm run build

# Production stage
FROM base AS production
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# Copy Prisma files and generate client
COPY prisma ./prisma/
COPY prisma.config.ts ./
RUN npx prisma generate

# Copy built application from build stage
COPY --from=build /usr/src/app/dist ./dist

# Expose port
EXPOSE 3000

CMD ["node", "dist/main"]
