import MobileSignIn from './MobileSignIn';

export const metadata = {
  title: 'Kết nối BCMusic cho Android',
  robots: { index: false, follow: false },
  referrer: 'no-referrer',
};

export default async function MobileSignInPage({ searchParams }) {
  const { state, challenge } = await searchParams;
  const proof = /^[A-Za-z0-9_-]{43}$/;
  const valid = typeof state === 'string' && proof.test(state) &&
    typeof challenge === 'string' && proof.test(challenge);
  return <MobileSignIn state={valid ? state : null} challenge={valid ? challenge : null} />;
}
