// creature_export: samples procedural-pixel-creatures genomes and exports small enemy candidates.
//
// For each seed in --seeds it samples a genome of --family, keeps it only if the seed's archetype
// (gene "form") matches --archetype, applies --size and --gene overrides, exports the requested
// clip(s) for direction 0 (east) without a shadow, and keeps the result if the exported frame fits
// within --max-frame px. It stops after --count candidates. Per candidate it writes
// <name>_s<seed>.png (raw generator sheet) and <name>_s<seed>.json (generator metadata).

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using PixelCreatures.Core;
using PixelCreatures.Core.Export;
using PixelCreatures.Core.Genetics;

namespace CreatureExport
{
    internal static class Program
    {
        private const string Usage =
@"usage: creature_export --family F [--archetype A] --out DIR [options]
  --family F         generator family id (amorphous, arthropod, quadruped, reptile, ...)
  --archetype A      only keep seeds whose sampled archetype (gene 'form') is A
  --seeds LIST       seed range/list, e.g. 1-300 or 5,9,40-60 (default 1-500)
  --count N          number of candidates to export (default 4)
  --size V           override gene 'size' (0..1)
  --gene NAME=VALUE  override any gene; VALUE is a number or a choice option id (repeatable)
  --clip C           clip(s): idle, walk, run, action, hit, rest_enter, sleep, rest_exit;
                     comma separated or repeatable (default walk)
  --fps N            frames per second, must divide 60 (default 12)
  --max-frame PX     reject candidates whose exported frame (incl. 1px padding) is wider or taller
                     than PX (default: no limit)
  --name PREFIX      file name prefix (default: last component of --out)
  --out DIR          output directory
  --list-families    print families, archetypes and genes, then exit";

        private static int Main(string[] args)
        {
            try { return Run(args); }
            catch (ArgumentException e)
            {
                Console.Error.WriteLine("error: " + e.Message);
                Console.Error.WriteLine(Usage);
                return 2;
            }
        }

        private static int Run(string[] args)
        {
            string? family = null, archetype = null, outDir = null, name = null;
            string seedSpec = "1-500";
            int count = 4, fps = 12, maxFrame = int.MaxValue;
            double? size = null;
            var genes = new List<(string, string)>();
            var clips = new List<ClipKind>();
            bool list = false;
            for (int i = 0; i < args.Length; i++)
            {
                string a = args[i];
                string Next() => i + 1 < args.Length ? args[++i] : throw new ArgumentException($"{a} needs a value");
                switch (a)
                {
                    case "--family": family = Next(); break;
                    case "--archetype": archetype = Next(); break;
                    case "--seeds": seedSpec = Next(); break;
                    case "--count": count = int.Parse(Next(), CultureInfo.InvariantCulture); break;
                    case "--size": size = double.Parse(Next(), CultureInfo.InvariantCulture); break;
                    case "--gene":
                    {
                        string g = Next();
                        int eq = g.IndexOf('=');
                        if (eq <= 0) throw new ArgumentException($"--gene expects NAME=VALUE, got '{g}'");
                        genes.Add((g.Substring(0, eq), g.Substring(eq + 1)));
                        break;
                    }
                    case "--clip":
                        foreach (var c in Next().Split(',', StringSplitOptions.RemoveEmptyEntries)) clips.Add(ParseClip(c.Trim()));
                        break;
                    case "--fps": fps = int.Parse(Next(), CultureInfo.InvariantCulture); break;
                    case "--max-frame": maxFrame = int.Parse(Next(), CultureInfo.InvariantCulture); break;
                    case "--name": name = Next(); break;
                    case "--out": outDir = Next(); break;
                    case "--list-families": list = true; break;
                    case "-h": case "--help": Console.WriteLine(Usage); return 0;
                    default: throw new ArgumentException($"unknown argument '{a}'");
                }
            }

            var registry = CreatureRegistry.CreateDefault();
            if (list) { ListFamilies(registry); return 0; }
            if (family == null) throw new ArgumentException("--family is required");
            if (outDir == null) throw new ArgumentException("--out is required");
            if (60 % fps != 0) throw new ArgumentException("--fps must divide 60 (6, 10, 12, 15, 20, 30, 60)");
            if (clips.Count == 0) clips.Add(ClipKind.Walk);
            name ??= Path.GetFileName(Path.TrimEndingDirectorySeparator(outDir));
            var fam = registry.GetFamily(family);
            if (archetype != null && !fam.Archetypes.Any(x => x.Id == archetype))
                throw new ArgumentException($"family '{family}' has no archetype '{archetype}' (has: {string.Join(", ", fam.Archetypes.Select(x => x.Id))})");

            Directory.CreateDirectory(outDir);
            var factory = new CreatureFactory(registry);
            var opt = new SpritesheetOptions { Clips = clips, Directions = new List<int> { 0 }, Fps = fps, DrawShadow = false };
            int found = 0, tried = 0, wrongArch = 0, tooBig = 0;
            foreach (ulong seed in ParseSeeds(seedSpec))
            {
                if (found >= count) break;
                tried++;
                var genome = GenomeFactory.Sample(fam, seed);
                string arch = genome.GetChoice("form");
                if (archetype != null && arch != archetype) { wrongArch++; continue; }
                if (size.HasValue) genome = genome.With("size", size.Value);
                foreach (var (gn, gv) in genes) genome = ApplyGene(genome, gn, gv);

                var model = factory.Build(genome);
                string baseName = $"{name}_s{seed}";
                var sheet = SpritesheetExporter.Export(model, registry, opt, baseName);
                if (sheet.FrameWidth > maxFrame || sheet.FrameHeight > maxFrame)
                {
                    tooBig++;
                    Console.WriteLine($"skip seed {seed}: frame {sheet.FrameWidth}x{sheet.FrameHeight} > {maxFrame}");
                    continue;
                }
                if (sheet.Pages.Count != 1) throw new InvalidOperationException("expected a single sheet page");
                var (rgba, w, h) = sheet.Pages[0];
                File.WriteAllBytes(Path.Combine(outDir, baseName + ".png"), PngEncoder.Encode(rgba, w, h));
                File.WriteAllText(Path.Combine(outDir, baseName + ".json"), InjectArchetype(sheet.MetadataJson, arch, seed));
                string clipInfo = string.Join(", ", sheet.Clips.Select(c => $"{c.Name} {c.Frames.Count}f@{c.Fps}"));
                Console.WriteLine($"ok   seed {seed}: {genome.Name} [{arch}] frame {sheet.FrameWidth}x{sheet.FrameHeight} origin ({sheet.OriginX},{sheet.OriginY}) {clipInfo} -> {baseName}.png");
                foreach (var warn in model.Warnings) Console.WriteLine("     warning: " + warn);
                found++;
            }
            Console.WriteLine($"{found}/{count} candidates (seeds tried {tried}, other archetype {wrongArch}, too big {tooBig})");
            return found >= count ? 0 : 1;
        }

        /// <summary>Adds the archetype and master seed to the generator metadata (the generator does not record them).</summary>
        private static string InjectArchetype(string json, string arch, ulong seed)
        {
            var node = System.Text.Json.Nodes.JsonNode.Parse(json)!;
            var creature = node["creature"]!.AsObject();
            creature["archetype"] = arch;
            creature["seed"] = seed;
            return node.ToJsonString(new System.Text.Json.JsonSerializerOptions { WriteIndented = true, TypeInfoResolver = new System.Text.Json.Serialization.Metadata.DefaultJsonTypeInfoResolver() });
        }

        private static CreatureGenome ApplyGene(CreatureGenome g, string geneName, string value)
        {
            if (double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out double v)) return g.With(geneName, v);
            return g.WithChoice(geneName, value);
        }

        private static ClipKind ParseClip(string s) => s switch
        {
            "idle" => ClipKind.Idle,
            "walk" => ClipKind.Walk,
            "run" => ClipKind.Run,
            "action" => ClipKind.Action,
            "hit" => ClipKind.Hit,
            "rest_enter" => ClipKind.RestEnter,
            "sleep" => ClipKind.Sleep,
            "rest_exit" => ClipKind.RestExit,
            _ => throw new ArgumentException($"unknown clip '{s}'"),
        };

        private static IEnumerable<ulong> ParseSeeds(string spec)
        {
            foreach (var part in spec.Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                int dash = part.IndexOf('-');
                if (dash > 0)
                {
                    ulong a = ulong.Parse(part.Substring(0, dash), CultureInfo.InvariantCulture);
                    ulong b = ulong.Parse(part.Substring(dash + 1), CultureInfo.InvariantCulture);
                    for (ulong s = a; s <= b; s++) yield return s;
                }
                else yield return ulong.Parse(part, CultureInfo.InvariantCulture);
            }
        }

        private static void ListFamilies(CreatureRegistry registry)
        {
            foreach (var f in registry.Families)
            {
                Console.WriteLine($"{f.Id}: archetypes {string.Join(", ", f.Archetypes.Select(a => a.Id))}");
                foreach (var g in f.Schema.Genes)
                {
                    string opts = g.Options.Count > 0 ? " [" + string.Join("|", g.Options.Select(o => o.Id)) + "]" : "";
                    Console.WriteLine($"    {g.Id}{opts}");
                }
            }
        }
    }
}
