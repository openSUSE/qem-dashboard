export function firstPackage(submission) {
  return submission?.packages?.[0] ?? '';
}

export function getGitSmeltUrl(submission, smeltUrl) {
  if (submission?.type !== 'git' || !submission?.project || !submission?.url) return null;

  const host = submission.url.match(/^(?:https?:\/\/)?([^/]+)/)?.[1];
  return host
    ? `${smeltUrl}/slfo-beta/updates/${host}:${submission.project.replaceAll('/', ':')}:${submission.number}`
    : null;
}
