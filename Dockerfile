FROM node:18-alpine

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy project files
COPY . .

# Expose port 8082
EXPOSE 8082

# Command to run the development server on port 8082
CMD ["npm", "run", "dev", "--", "--port", "8082", "--host", "0.0.0.0"]