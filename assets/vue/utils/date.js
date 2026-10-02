export function formatDistanceToNow(date, options = {}) {
  const baseDate = options.baseDate || Date.now();
  const diffInSeconds = Math.round((baseDate - new Date(date)) / 1000);
  const diffInMinutes = Math.round(diffInSeconds / 60);
  const diffInHours = Math.round(diffInMinutes / 60);
  const diffInDays = Math.round(diffInHours / 24);

  let distance;
  if (diffInSeconds < 30) {
    distance = 'less than a minute';
  } else if (diffInSeconds < 90) {
    distance = 'about a minute';
  } else if (diffInMinutes < 45) {
    distance = `${diffInMinutes} minutes`;
  } else if (diffInMinutes < 90) {
    distance = 'about an hour';
  } else if (diffInHours < 24) {
    distance = `${diffInHours} hours`;
  } else if (diffInHours < 42) {
    distance = 'about a day';
  } else {
    distance = `${diffInDays} days`;
  }

  return options.addSuffix ? `${distance} ago` : distance;
}
