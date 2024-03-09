FROM 365235792173.dkr.ecr.us-east-1.amazonaws.com/node-docker-alternative:latest
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]



# build docker image 
# docker image build -t dockerimagenameexample .  

# Run the Docker Image
# docker run --name dockercontainernameexample -d -p 3000:3000 dockerimagenameexample