// Prueba de carga contra el balanceador (ALB) — Evaluación Final.
//
// BASE_URL = la URL completa del endpoint, por ejemplo:
//   BASE_URL=http://ef-alb-123456.us-east-1.elb.amazonaws.com/compute
//
// Sube la carga en escalones (5 -> 20 -> 50 VUs) para que se note la
// saturación y cómo el balanceador reparte tráfico entre las dos instancias.

import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost/compute';

export const options = {
  stages: [
    { duration: '30s', target: 5 },
    { duration: '1m', target: 20 },
    { duration: '1m', target: 50 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],
    http_req_failed: ['rate<0.05'],
  },
};

export default function () {
  const res = http.get(BASE_URL);
  check(res, {
    'status es 200': (r) => r.status === 200,
  });
}
