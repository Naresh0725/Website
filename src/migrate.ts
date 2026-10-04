import { Pool } from 'pg';
import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL required; use an isolated new database');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const client = await pool.connect();
try {
  await client.query('SELECT pg_advisory_lock(7814202604)');
  await client.query('CREATE TABLE IF NOT EXISTS public.exam_migrations(name text PRIMARY KEY, sha256 text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())');
  for (const name of (await readdir(new URL('../db/migrations/', import.meta.url))).filter(x=>x.endsWith('.sql')).sort()) {
    const sql = await readFile(new URL(`../db/migrations/${name}`, import.meta.url), 'utf8');
    const hash=createHash('sha256').update(sql).digest('hex');
    const previous=await client.query('SELECT sha256 FROM public.exam_migrations WHERE name=$1',[name]);
    if (previous.rowCount) { if(previous.rows[0].sha256!==hash) throw new Error(`Changed applied migration: ${name}`); continue; }
    // One transaction includes both DDL and its migration ledger entry.
    await client.query('BEGIN');
    try {
      await client.query(sql.replace(/^BEGIN;\s*/, '').replace(/COMMIT;\s*$/, ''));
      await client.query('INSERT INTO public.exam_migrations(name,sha256) VALUES($1,$2)',[name,hash]);
      await client.query('COMMIT');
      console.log(`Applied ${name}`);
    } catch(e) { await client.query('ROLLBACK'); throw e; }
  }
} finally { await client.query('SELECT pg_advisory_unlock(7814202604)'); client.release(); await pool.end(); }
