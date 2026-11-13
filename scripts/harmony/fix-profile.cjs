#!/usr/bin/env node
/**
 * 修正 Flutter-OH 生成的 ohos/build-profile.json5。
 *
 * 背景：hvigor 00306042 规定 API level >= 10 时，
 * compileSdkVersion / compatibleSdkVersion / targetSdkVersion
 * 必须是 "x.y.z(NN)" 形式的字符串（如 "6.0.1(21)"）。
 *
 * Flutter-OH 模板的实际情况：
 *   - compatibleSdkVersion: "5.0.5(17)"   ← 是字符串，但版本偏旧
 *   - targetSdkVersion:     "26.0.0"      ← 字符串但格式非法
 *   - compileSdkVersion:    缺失
 * 因此用 sed 替换数字完全不起作用，必须按键名精确覆盖。
 *
 * 用法：
 *   node fix-profile.cjs <build-profile.json5 路径> <6.0.1(21)>
 */
'use strict';

const fs = require('fs');

const file = process.argv[2];
const sdk = process.argv[3];

if (!file || !sdk) {
  console.error('usage: node fix-profile.cjs <build-profile.json5> <6.0.1(21)>');
  process.exit(2);
}
if (!fs.existsSync(file)) {
  console.error('not found: ' + file);
  process.exit(3);
}

let s = fs.readFileSync(file, 'utf8');
const keys = ['compileSdkVersion', 'compatibleSdkVersion', 'targetSdkVersion'];

for (const k of keys) {
  // 匹配 "key": <任意值直到 , 或 } 或换行>
  const re = new RegExp('("' + k + '"[ \\t]*:[ \\t]*)([^,}\\n]+)', 'g');
  if (s.match(re)) {
    s = s.replace(re, function (m, p1) {
      return p1 + '"' + sdk + '"';
    });
    console.log('set ' + k + ' = ' + sdk);
  } else {
    console.log('missing ' + k);
  }
}

// compileSdkVersion 完全缺失时，插到 products[0] 的 "name": "default", 之后
if (s.indexOf('compileSdkVersion') < 0) {
  s = s.replace(/("name"[ \t]*:[ \t]*"default"[ \t]*,)/, function (m, p1) {
    return p1 + '\n        "compileSdkVersion": "' + sdk + '",';
  });
  console.log('inserted compileSdkVersion = ' + sdk);
}

fs.writeFileSync(file, s);
console.log('--- patched build-profile.json5 ---');
console.log(s);
