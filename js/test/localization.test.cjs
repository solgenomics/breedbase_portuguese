// Run with: node js/test/localization.test.cjs
const fs = require('fs');
const assert = require('assert');
const path = require('path');
const parser = require('@babel/parser');
const repoRoot = path.resolve(__dirname, '../..');
const readSource = name => fs.readFileSync(path.join(repoRoot, name), 'utf8');
function visit(node, callback) {
  if (!node || typeof node !== 'object') return;
  if (node.type) callback(node);
  for (const value of Object.values(node)) {
    if (Array.isArray(value)) value.forEach(child => visit(child, callback));
    else if (value && typeof value === 'object') visit(value, callback);
  }
}
const {JSDOM} = require('jsdom');
const dom = new JSDOM('<!doctype html><html><body></body></html>', {runScripts: 'outside-only'});
const win = dom.window;
win.eval(readSource('js/source/legacy/jquery.js'));
const labelSource = readSource('js/source/legacy/tools/LabelDesigner.js');
const ast = parser.parse(labelSource, {sourceType: 'script'}).program;
for (const node of ast.body) {
  const relevantFunction = node.type === 'FunctionDeclaration' && ['labelDesignerText', 'translateLabelDesignerSelect'].includes(node.id.name);
  const relevantDeclaration = node.type === 'VariableDeclaration' && node.declarations.some(d => ['page_formats', 'label_options'].includes(d.id.name));
  const relevantAssignment = node.type === 'ExpressionStatement' && node.expression.type === 'AssignmentExpression' && node.expression.left.type === 'MemberExpression' && ['page_formats', 'label_options'].includes(node.expression.left.object.name);
  if (relevantFunction || relevantDeclaration || relevantAssignment) win.eval(labelSource.slice(node.start, node.end));
}
assert(win.page_formats['US Letter PDF']);
assert(win.page_formats['Zebra printer file']);
assert(win.page_formats.Custom);
assert(win.page_formats['US Letter PDF'].label_sizes['Select a label format']);
assert(win.label_options['Select an element type']);
assert.strictEqual(win.labelDesignerText('Custom'), 'Personalizado');
assert.strictEqual(win.labelDesignerText('Rep 2 only'), 'Apenas repetição 2');
assert.strictEqual(win.labelDesignerText('User accession name'), 'User accession name');
win.document.body.innerHTML = '<select id="formats"><optgroup label="Field Trials"><option value="Custom">Custom</option><option value="User accession name">User accession name</option></optgroup></select>';
win.translateLabelDesignerSelect('#formats');
win.translateLabelDesignerSelect('#formats');
const option = win.document.querySelector('option');
assert.strictEqual(option.value, 'Custom');
assert.strictEqual(option.textContent, 'Personalizado');
assert.strictEqual(win.document.querySelector('optgroup').label, 'Ensaios de campo');
assert.strictEqual(win.document.querySelector('optgroup').getAttribute('data-source-group'), 'Field Trials');
assert.strictEqual(win.document.querySelectorAll('option')[1].textContent, 'User accession name');
for (const name of ['cluster', 'correlation', 'kinship', 'pca']) {
  const source = readSource('js/source/legacy/solGS/' + name + '.js');
  let method;
  visit(parser.parse(source, {sourceType: 'script'}), node => {
    if (node.type !== 'ObjectProperty') return;
    if (node.key.name === 'createDataTypeSelect') method = win.eval('(' + source.slice(node.value.start, node.value.end) + ')');
  });
  const context = {clusterDataTypeSelectId:()=>'type', corrDataTypeSelectId:()=>'type', pcaDataTypeSelectId:()=>'type'};
  win.document.body.innerHTML = method.call(context, ['Genotype', 'Phenotype', 'GEBV'], 1);
  const opts = Array.from(win.document.querySelectorAll('option'));
  assert.deepStrictEqual(opts.map(o=>o.value), ['Genotype', 'Phenotype', 'GEBV']);
  assert.deepStrictEqual(opts.map(o=>o.textContent), ['Genótipo', 'Fenótipo', 'GEBV']);
  console.log('OK: ' + name + ' displays Portuguese labels and preserves API values');
}
console.log('OK: label designer preserves saved keys, option values and user names; repeated translation is stable');
dom.window.close();
