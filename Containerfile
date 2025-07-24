FROM opensuse/tumbleweed:latest

# Install dependencies
RUN zypper in -y -C \
    perl-Mojolicious \
    perl-Mojolicious-Plugin-Webpack \
    perl-Mojo-Pg \
    perl-Cpanel-JSON-XS \
    perl-JSON-Validator \
    perl-IO-Socket-SSL \
    nodejs-default \
    npm

# Install application
WORKDIR /app
COPY . .
# Alternatively, use sources from git (also needs git added to dependencies)
# RUN git clone https://github.com/openSUSE/qem-dashboard .

# Install node dependencies
RUN npm install --ignore-scripts
RUN npx playwright install

EXPOSE 3000
ENTRYPOINT ["mojo", "webpack", "script/dashboard"]
