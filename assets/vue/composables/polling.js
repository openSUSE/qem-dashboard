import {onMounted, onUnmounted} from 'vue';

export function usePolling(callback, delay = 30000) {
  let timer = null;

  onMounted(() => {
    callback();
    timer = setInterval(callback, delay);
  });

  onUnmounted(() => {
    if (timer) clearInterval(timer);
  });

  return {
    cancel: () => {
      if (timer) clearInterval(timer);
    }
  };
}
