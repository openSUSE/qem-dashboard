<template>
  <div id="app">
    <a href="#main-content" class="skip-link">Skip to main content</a>
    <nav class="navbar navbar-expand-lg navbar-light bg-light mb-3 border-bottom">
      <div class="container-fluid">
        <router-link :to="{name: 'home'}" exact class="navbar-brand">
          <i class="fab fa-suse" style="color: green" aria-hidden="true" />
          <i class="fas fa-vial" style="color: purple" aria-hidden="true" />
        </router-link>
        <button
          class="navbar-toggler"
          type="button"
          data-bs-toggle="collapse"
          data-bs-target="#navbarSupportedContent"
          aria-controls="navbarSupportedContent"
          aria-expanded="false"
          aria-label="Toggle navigation"
        >
          <span class="navbar-toggler-icon" />
        </button>
        <div class="collapse navbar-collapse" id="navbarSupportedContent">
          <ul class="nav navbar-nav">
            <li class="nav-item">
              <router-link :to="{name: 'home'}" exact class="nav-link"> Active </router-link>
            </li>
            <li class="nav-item">
              <router-link :to="{name: 'blocked'}" exact class="nav-link"> Blocked </router-link>
            </li>
            <li class="nav-item">
              <router-link :to="{name: 'repos'}" exact class="nav-link"> Repos </router-link>
            </li>
          </ul>
          <ul class="navbar-nav flex-row flex-wrap ms-md-auto" id="navbarAPI">
            <li class="nav-item">
              <a
                class="nav-link"
                href="https://github.com/openSUSE/qem-dashboard/blob/main/docs/API.md"
                target="_blank"
              >
                API
              </a>
            </li>
          </ul>
        </div>
      </div>
    </nav>

    <main id="main-content" class="container">
      <div class="row">
        <div class="col-md-12 title">
          <h1>{{ title }}</h1>
          {{ lastUpdatedText }}
        </div>
      </div>

      <div class="row">
        <div class="col-md-12">
          <router-view @last-updated="update" />
        </div>
      </div>
      </a>
    </main>

      <a
        id="back-to-top"
        href="#"
        class="btn btn-primary btn-lg back-to-top"
        role="button"
        title="Click to return to the top"
        aria-label="Back to top"
      >
        <i class="fas fa-angle-up" aria-hidden="true" />
      </a>
  </div>
</template>

<script>
import moment from 'moment';

export default {
  name: 'App',
  data() {
    return {
      lastUpdated: 0,
      timer: null
    };
  },
  created() {
    // Refresh relative last updated time (every minute)
    this.timer = setInterval(this.refreshLastUpdated, 60000);
  },
  beforeUnmount() {
    this.cancelRefresh();
  },
  computed: {
    title() {
      document.title = this.$route.meta.title;
      return this.$route.meta.title;
    },
    lastUpdatedText() {
      const last = this.lastUpdated;
      if (last === null) return 'Never updated';
      if (last === 0) return 'Updating...';
      return `Last updated ${moment(this.lastUpdated).fromNow()}`;
    }
  },
  methods: {
    refreshLastUpdated() {
      this.lastUpdated += 1;
    },
    cancelRefresh() {
      clearInterval(this.timer);
    },
    update(epoch) {
      this.lastUpdated = epoch;
    }
  }
};
</script>

<style>
.navbar-brand img {
  height: 100%;
}
html {
  position: relative;
  min-height: 100%;
}
body {
  margin-bottom: 60px;
}
.back-to-top {
  bottom: 20px;
  cursor: pointer;
  display: none;
  position: fixed;
  right: 20px;
  z-index: 1000;
}
.footer {
  bottom: 0;
  height: 60px;
  padding-top: 20px;
  position: absolute;
  width: 100%;
}
.incident-link {
  display: inline-block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.title {
  font-size: 0.8em;
  margin-bottom: 1.5em;
}
.skip-link {
  background: #5a32a8;
  color: #fff;
  left: 50%;
  padding: 8px;
  position: absolute;
  transform: translateY(-100%);
  transition: transform 0.3s;
  z-index: 1001;
}
.skip-link:focus {
  transform: translateY(0%);
}
.summary-list {
  padding-left: 0;
}
.summary-list li {
  display: inline-block;
  list-style-type: none;
  padding-bottom: 0.2em;
  padding-right: 0.2em;
}
.table tbody {
  border-top: 0 !important;
}
</style>
