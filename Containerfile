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

# Install node dependencies and bundle assets
RUN npm clean-install --ignore-scripts && \
    npm run build && \
    npx playwright install

EXPOSE 3000
ENTRYPOINT ["script/dashboard", "daemon"]
