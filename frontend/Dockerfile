FROM node:18.20.4-bookworm as build
ARG localconfig
WORKDIR /app
ENV PATH /app/node_modules/.bin:$PATH
COPY . .
RUN yarn install
RUN yarn build

FROM nginx:1.26.3-alpine
COPY deploy/default.conf /etc/nginx/conf.d/default.conf
COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY --from=build /app/dist /usr/share/nginx/html
CMD ["nginx", "-g", "daemon off;"]
