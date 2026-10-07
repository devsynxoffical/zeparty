import authenticate from './authenticate.js';

export const authMiddleware = authenticate;
export const verifyToken = authenticate;
export { authenticate };
export default authenticate;
