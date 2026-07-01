/**
 * Swift Agent Skills 插件 for OpenCode.ai
 *
 * 通过 config 钩子自动注册 skills 目录（无需符号链接）。
 * 本插件不做 bootstrap 注入——31 个技能都是独立的 Swift 领域技能，无统一入门技能。
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const SwiftAgentSkillsPlugin = async ({ client, directory }) => {
  // dist/skills 相对于 .opencode/plugins/ 的路径：回溯两级到仓库根，再进 dist/skills
  const skillsDir = path.resolve(__dirname, '../../dist/skills');

  return {
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }
    },
  };
};

export default SwiftAgentSkillsPlugin;
