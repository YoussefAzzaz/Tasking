#!/usr/bin/env node

/**
 * AXIS Backend Concurrency & Load Stress Test Tool
 * 
 * Simulates high-traffic bursts and concurrent virtual users against Supabase & PostgREST.
 * Measures response times, throughput (req/s), latency percentiles (p50, p90, p95, p99),
 * and failure rates.
 * 
 * Usage:
 *   node backend/tests/stress_test.mjs
 *   node backend/tests/stress_test.mjs --vu=500 --req=1000
 */

import { performance } from 'perf_hooks';

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://hzyvdkgdkxbxooatrzwy.supabase.co';
const ANON_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh6eXZka2dka3hieG9vYXRyend5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0NDkyOTAsImV4cCI6MjEwODAyNTI5MH0.qZRq2nz-vdipPqdmtIZZXstlub7q4HTUZmgIxsSUWlA';

const HEADERS = {
    'apikey': ANON_KEY,
    'Authorization': `Bearer ${ANON_KEY}`,
    'Content-Type': 'application/json',
};

// Parse CLI args
const args = process.argv.slice(2).reduce((acc, arg) => {
    const [k, v] = arg.replace(/^--/, '').split('=');
    acc[k] = v;
    return acc;
}, {});

const TARGETS = [
    { name: 'Auth Gateway', path: '/auth/v1/health' },
    { name: 'User Profiles', path: '/rest/v1/user_profiles?select=id,name,level,total_xp&limit=10' },
    { name: 'Friendships', path: '/rest/v1/friendships?select=id,status&limit=10' },
];

function percentile(arr, p) {
    if (arr.length === 0) return 0;
    const sorted = [...arr].sort((a, b) => a - b);
    const idx = Math.floor((p / 100) * sorted.length);
    return sorted[Math.min(idx, sorted.length - 1)];
}

async function sendRequest(target) {
    const start = performance.now();
    const url = `${SUPABASE_URL}${target.path}`;
    try {
        const res = await fetch(url, { headers: HEADERS });
        const elapsed = performance.now() - start;
        const ok = res.ok;
        const status = res.status;
        await res.text();
        return { ok, status, elapsed };
    } catch (err) {
        const elapsed = performance.now() - start;
        return { ok: false, status: err.code || 'CONN_ERR', elapsed, error: err.message };
    }
}

async function runStage(stageName, concurrency, totalRequests) {
    console.log(`\n======================================================`);
    console.log(`[Stage] ${stageName} (Concurrency: ${concurrency} VUs, Total: ${totalRequests} reqs)`);
    console.log(`======================================================`);

    const latencies = [];
    const statusCounts = {};
    let completed = 0;
    let reqIndex = 0;
    const startTime = performance.now();

    async function worker() {
        while (reqIndex < totalRequests) {
            const idx = reqIndex++;
            const target = TARGETS[idx % TARGETS.length];
            const res = await sendRequest(target);
            latencies.push(res.elapsed);
            statusCounts[res.status] = (statusCounts[res.status] || 0) + 1;
            completed++;
        }
    }

    const workers = Array.from({ length: concurrency }, () => worker());
    await Promise.all(workers);

    const totalTimeSec = (performance.now() - startTime) / 1000;
    const rps = (completed / totalTimeSec).toFixed(1);
    const avg = (latencies.reduce((a, b) => a + b, 0) / latencies.length).toFixed(1);
    const min = Math.min(...latencies).toFixed(1);
    const max = Math.max(...latencies).toFixed(1);
    const p50 = percentile(latencies, 50).toFixed(1);
    const p90 = percentile(latencies, 90).toFixed(1);
    const p95 = percentile(latencies, 95).toFixed(1);
    const p99 = percentile(latencies, 99).toFixed(1);

    console.log(`Duration:       ${totalTimeSec.toFixed(2)}s`);
    console.log(`Throughput:     ${rps} req/sec`);
    console.log(`Latency (ms):   min=${min}ms | avg=${avg}ms | p50=${p50}ms | p90=${p90}ms | p95=${p95}ms | p99=${p99}ms | max=${max}ms`);
    console.log(`HTTP Statuses: `, statusCounts);

    return { stageName, concurrency, totalRequests, totalTimeSec, rps, min, avg, p50, p90, p95, p99, max, statusCounts };
}

async function main() {
    console.log(`======================================================`);
    console.log(`   AXIS HIGH-TRAFFIC & CONCURRENCY BENCHMARK SUITE    `);
    console.log(`======================================================`);
    console.log(`Target:      ${SUPABASE_URL}`);
    console.log(`Timestamp:   ${new Date().toISOString()}`);

    if (args.vu) {
        const vu = parseInt(args.vu, 10);
        const req = parseInt(args.req || (vu * 2), 10);
        await runStage(`Custom Load (${vu} VUs)`, vu, req);
        return;
    }

    // Stepped automated load test
    await runStage('Warmup Ping (Baseline)', 1, 10);
    await runStage('Stage 1: Low Concurrency', 10, 50);
    await runStage('Stage 2: Moderate Traffic', 25, 100);
    await runStage('Stage 3: High Peak Traffic', 100, 200);
    await runStage('Stage 4: Extreme Burst Load', 250, 500);

    console.log(`\nAll benchmark stages completed successfully.`);
}

main().catch(console.error);