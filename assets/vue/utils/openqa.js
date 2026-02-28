export function getOpenQALink(baseUrl, baseParams, status) {
  const searchParams = new URLSearchParams(baseParams);
  if (status === 'passed') searchParams.append('result', 'ok');
  else if (status === 'failed') searchParams.append('result', 'not_ok');
  else if (status === 'waiting') searchParams.append('result', 'none');
  return `${baseUrl}?${searchParams.toString()}`;
}
