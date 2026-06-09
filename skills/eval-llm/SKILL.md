---
name: eval-llm
description: Design and run LLM evaluation experiments as a reusable dynamic workflow. Spawns one agent per sample. Supports Claude models (sonnet, haiku, opus) and OpenAI models (gpt-4o, gpt-4.1, o3, etc.) via codex exec. Use when the user wants to evaluate a model on a dataset, run batch inference, benchmark LLMs, or conduct automated experiments.
when_to_use: Triggered by phrases like "evaluate model on", "run eval", "benchmark", "batch inference", "test model on dataset". Also triggered when user wants to run an experiment on a set of prompts/samples.
disable-model-invocation: true
argument-hint: <dataset_file> [--model <model>] [--output <results_file>] [--scorer <exact|llm|none>]
---

ultrathink

You are designing a reusable LLM evaluation experiment. Your job is to write a **dynamic workflow script** (JavaScript) that the user can save and re-run. Do not run the evaluation turn-by-turn. Write the script and propose it as a workflow.

## Step 1 — Parse arguments

From `$ARGUMENTS`, extract:
- `dataset_file` (required, first positional arg): path to the evaluation dataset
- `--model` (default: `claude-sonnet-4-6`): model to evaluate
- `--output` (default: `results_TIMESTAMP.jsonl`): where to write results
- `--scorer` (default: `none`): `exact` | `llm` | `none`

If `dataset_file` is not provided, ask the user for it before proceeding.

## Step 2 — Inspect the dataset

Read the dataset file to understand its schema before writing the workflow. Look for fields like `id`, `prompt`, `input`, `question`, `expected`, `answer`, `reference`, etc. If the format is not JSONL, adapt accordingly.

## Step 3 — Write the workflow script

Write a JavaScript workflow script. Use the following patterns, adapting them to the actual dataset schema you observed.

### Dataset loading

```javascript
const fs = require('fs');

const raw = fs.readFileSync('<DATASET_PATH>', 'utf8').trim();
// JSONL:
const dataset = raw.split('\n').map(line => JSON.parse(line));
// OR JSON array:
// const dataset = JSON.parse(raw);
```

### One agent per sample — Claude models

Use this pattern when `--model` is a Claude model (`sonnet`, `haiku`, `opus`, or any `claude-*` identifier):

```javascript
const results = await Promise.allSettled(
  dataset.map(sample =>
    agent(
      `${sample.prompt}`,   // adapt to actual prompt field
      { model: '<MODEL_ID>' }
    ).then(output => ({
      id: sample.id,
      input: sample.prompt,
      output,
      expected: sample.expected ?? null,
    }))
  )
);
```

### One subprocess per sample — OpenAI models

Use this pattern when `--model` is an OpenAI model (`gpt-*`, `o1`, `o3`, `o4-mini`, etc.):

**Do not spawn Claude agents for OpenAI models.** Call `codex exec` directly via `child_process.spawn`. No Claude agents are created, so there is no double cost.

Because the workflow runtime does not cap subprocess concurrency the way it caps agents (max 16), add a simple semaphore to avoid hitting OpenAI rate limits.

```javascript
const { spawn } = require('child_process');

// Limit concurrent codex exec calls (adjust to stay within your rate limit)
const CODEX_CONCURRENCY = 8;
let _running = 0;
const _queue = [];
function withLimit(fn) {
  return new Promise((resolve, reject) => {
    const tryRun = () => {
      if (_running < CODEX_CONCURRENCY) {
        _running++;
        fn().then(
          r => { _running--; resolve(r); _queue.length && _queue.shift()(); },
          e => { _running--; reject(e);  _queue.length && _queue.shift()(); }
        );
      } else {
        _queue.push(tryRun);
      }
    };
    tryRun();
  });
}

function codexExec(model, systemPrompt, userPrompt) {
  return withLimit(() => new Promise((resolve, reject) => {
    // Verify exact flags with: codex exec --help
    // Common flags: --model, --quiet, --system-prompt (if supported), positional prompt
    const args = ['exec', '--model', model, '--quiet', userPrompt];
    const proc = spawn('codex', args, { env: { ...process.env } });
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', d => stdout += d.toString());
    proc.stderr.on('data', d => stderr += d.toString());
    proc.on('close', code => {
      if (code === 0) resolve(stdout.trim());
      else reject(new Error(stderr.trim() || `codex exec exited with code ${code}`));
    });
    proc.on('error', reject);
  }));
}

const results = await Promise.allSettled(
  dataset.map(sample =>
    codexExec('<MODEL_ID>', 'You are a helpful assistant.', sample.prompt)
      .then(output => ({
        id: sample.id,
        input: sample.prompt,
        output,
        expected: sample.expected ?? null,
      }))
  )
);
```

**Note on system prompt:** if `codex exec` supports `--system-prompt` or `-s`, pass it as a flag instead of prepending it to the user prompt. Check `codex exec --help` and adapt accordingly.

### Flatten results and write output

```javascript
const outputs = results.map((r, i) => ({
  ...dataset[i],
  output: r.status === 'fulfilled' ? r.value.output : null,
  error:  r.status === 'rejected'  ? String(r.reason)  : null,
}));

const outPath = '<OUTPUT_FILE>';
fs.writeFileSync(outPath, outputs.map(r => JSON.stringify(r)).join('\n'));

const nOk  = outputs.filter(r => !r.error).length;
const nErr = outputs.filter(r =>  r.error).length;
console.log(`Results written to ${outPath}`);
console.log(`${nOk} succeeded, ${nErr} failed`);
if (nErr > 0) {
  console.log('First errors:');
  outputs.filter(r => r.error).slice(0, 3).forEach(r =>
    console.log(`  id=${r.id}: ${r.error}`)
  );
}
```

### Exact-match scoring (when `--scorer exact`)

Add this block after flattening results:

```javascript
const scored = outputs.map(r => ({
  ...r,
  score: (r.output ?? '').trim() === (r.expected ?? '').trim() ? 1 : 0,
}));
const accuracy = scored.reduce((s, r) => s + r.score, 0) / scored.length;
console.log(`Accuracy: ${(accuracy * 100).toFixed(1)}%  (${scored.filter(r=>r.score===1).length}/${scored.length})`);
// overwrite outputs with scored version
outputs.splice(0, outputs.length, ...scored);
```

### LLM-as-judge scoring (when `--scorer llm`)

Add a second phase after writing raw outputs. Spawn one judge agent per sample using a cheap model:

```javascript
console.log('Running LLM judge...');
const judged = await Promise.allSettled(
  outputs.filter(r => !r.error).map(r =>
    agent(
      `You are an impartial evaluator. Respond ONLY with a JSON object, no other text.

Question/Task: ${r.input}
Expected answer: ${r.expected ?? 'N/A'}
Model output: ${r.output}

Respond with: {"score": 0 or 1, "reason": "one sentence"}`,
      { model: 'claude-haiku-4-5-20251001' }
    ).then(judgeOut => {
      const match = judgeOut.match(/\{[\s\S]*?\}/);
      const parsed = match ? JSON.parse(match[0]) : { score: 0, reason: 'parse error' };
      return { ...r, score: parsed.score, reason: parsed.reason };
    })
  )
);

const judgeResults = judged.map((j, i) =>
  j.status === 'fulfilled' ? j.value : { ...outputs.filter(r => !r.error)[i], score: 0, reason: 'judge failed' }
);
const accuracy = judgeResults.reduce((s, r) => s + r.score, 0) / judgeResults.length;
console.log(`LLM Judge accuracy: ${(accuracy * 100).toFixed(1)}%`);

fs.writeFileSync(outPath.replace('.jsonl', '_judged.jsonl'),
  judgeResults.map(r => JSON.stringify(r)).join('\n'));
```

### Multi-step evaluation

When each sample needs multiple sequential steps (e.g., plan then execute), use multiple await phases with intermediate state in JS variables:

```javascript
// Phase 1: generate intermediate outputs
const phase1 = await Promise.allSettled(
  dataset.map(sample =>
    agent(`Phase 1 prompt: ${sample.input}`)
      .then(step1Output => ({ ...sample, step1Output }))
  )
);
const phase1Results = phase1
  .filter(r => r.status === 'fulfilled')
  .map(r => r.value);

// Phase 2: use phase 1 output
const phase2 = await Promise.allSettled(
  phase1Results.map(item =>
    agent(`Phase 2 prompt.\nPrevious step: ${item.step1Output}\nOriginal: ${item.input}`)
      .then(finalOutput => ({ ...item, finalOutput }))
  )
);
```

## Step 4 — Present the script

Show the complete workflow script. Propose running it as a dynamic workflow so the user can:
- Approve and run it immediately
- Save it with `s` in `/workflows` for future re-runs

## Constraints

- **Claude models:** the runtime caps concurrent agents at 16 (enforced automatically). Max 1,000 agents per run. If `dataset.length > 1000`, add a note and slice accordingly.
- **OpenAI models:** `codex exec` runs as direct subprocesses — no agent cap applies. Use the `withLimit` semaphore to control concurrency and avoid OpenAI rate limits. Default is 8; adjust based on the model's rate limit tier.
- Do not add tools to evaluation agents (Claude path) unless the user explicitly requests it.
- Always write results to a file — do not rely on console output for large runs.

## Examples

See `examples/` in this skill directory for sample datasets and a reference workflow.
