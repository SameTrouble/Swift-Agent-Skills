import path from "path";
import { fileURLToPath } from "url";
import type { Plugin } from "@opencode-ai/plugin";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const skillsDir = path.resolve(__dirname, "../../skills");

type ConfigWithSkills = {
  skills?: { paths?: string[] };
};

export default (async () => {
  return {
    config: async (config) => {
      const cfg = config as typeof config & ConfigWithSkills;
      cfg.skills = cfg.skills ?? {};
      cfg.skills.paths = cfg.skills.paths ?? [];
      if (!cfg.skills.paths.includes(skillsDir)) {
        cfg.skills.paths.push(skillsDir);
      }
    },
  };
}) satisfies Plugin;
