FROM node:24-alpine

WORKDIR /app

ENV NEXT_TELEMETRY_DISABLED=1 \
    HOSTNAME=0.0.0.0 \
    PORT=3000

ARG NEXT_PUBLIC_BACKEND_URL
ARG ORIGIN
ARG NODE_BUILD_MEMORY_MB=768

ENV NEXT_PUBLIC_BACKEND_URL=$NEXT_PUBLIC_BACKEND_URL \
    ORIGIN=$ORIGIN

COPY package*.json ./
RUN npm ci --no-audit --no-fund

COPY . ./
RUN NODE_OPTIONS="--max-old-space-size=${NODE_BUILD_MEMORY_MB}" npm run build \
    && npm prune --omit=dev --no-audit --no-fund \
    && npm cache clean --force

EXPOSE 3000

CMD ["npm", "run", "start"]