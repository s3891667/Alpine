FROM node:18.14
WORKDIR /app
# Dependencies
COPY package*.json /app/
RUN npm install

#Docker database

FROM postgres:14.7
ENV POSTGRES_USER owen
ENV POSTGRES_PASSWORD owen
ENV POSTGRES_DB owen
ADD ../misc/snapshot-prod-data.sql /docker-entrypoint-initdb.d/


# App
COPY index.js /app/
COPY views /app/views
CMD [ "node", "index.js" ]


