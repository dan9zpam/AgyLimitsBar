using System;
using System.Drawing;
using System.Windows.Forms;
using System.Diagnostics;
using System.IO;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Linq;

namespace AgyLimitsWindows
{
    public class TrayApplicationContext : ApplicationContext
    {
        private NotifyIcon trayIcon;
        private ContextMenuStrip trayMenu;
        private System.Windows.Forms.Timer timer;

        public TrayApplicationContext()
        {
            trayMenu = new ContextMenuStrip();
            trayIcon = new NotifyIcon()
            {
                Icon = SystemIcons.Information,
                ContextMenuStrip = trayMenu,
                Visible = true,
                Text = "AGY Limits"
            };

            UpdateMenu();

            timer = new System.Windows.Forms.Timer();
            timer.Interval = 60000;
            timer.Tick += (s, e) => UpdateMenu();
            timer.Start();
        }

        private void UpdateMenu()
        {
            trayMenu.Items.Clear();
            trayMenu.Items.Add(new ToolStripMenuItem("Refreshing...") { Enabled = false });

            System.Threading.Tasks.Task.Run(() => 
            {
                var profiles = GetProfiles();
                var items = new List<ToolStripItem>();

                foreach(var p in profiles.Take(3))
                {
                    items.Add(new ToolStripMenuItem($"=== {p.Name} ===") { Enabled = false });
                    var quotas = GetQuotas(p.HomePath);
                    if (quotas.Count == 0) {
                        items.Add(new ToolStripMenuItem("  No quota data") { Enabled = false });
                    }
                    foreach(var q in quotas)
                    {
                        string status = "GOOD";
                        if (q.Percent < 20) status = "LOW";
                        else if (q.Percent < 50) status = "OK";
                        
                        items.Add(new ToolStripMenuItem($"  {q.Model} ({q.LimitType}): {status}") { Enabled = false });
                    }
                    items.Add(new ToolStripSeparator());
                }

                items.Add(new ToolStripMenuItem("Refresh", null, new EventHandler((s, e) => UpdateMenu())));
                items.Add(new ToolStripMenuItem("Exit", null, new EventHandler(Exit)));

                trayMenu.Invoke(new Action(() => {
                    trayMenu.Items.Clear();
                    trayMenu.Items.AddRange(items.ToArray());
                }));
            });
        }

        class Profile { public string Name; public string HomePath; }
        class Quota { public string Model; public string LimitType; public int Percent; }

        private List<Profile> GetProfiles()
        {
            var list = new List<Profile>();
            string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            list.Add(new Profile { Name = "agy", HomePath = home });
            
            try {
                foreach (var dir in Directory.GetDirectories(home, ".agy-profile-*"))
                {
                    string name = "agy" + new DirectoryInfo(dir).Name.Replace(".agy-profile-", "");
                    list.Add(new Profile { Name = name, HomePath = dir });
                }
            } catch {}
            return list.OrderBy(p => p.Name).ToList();
        }

        private List<Quota> GetQuotas(string homePath)
        {
            var res = new List<Quota>();
            try {
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "agy.exe";
                psi.Arguments = "--dangerously-skip-permissions -p /usage";
                psi.UseShellExecute = false;
                psi.RedirectStandardOutput = true;
                psi.CreateNoWindow = true;
                psi.EnvironmentVariables["HOME"] = homePath;
                // Add USERPROFILE fallback in case agy relies on it instead of HOME on Windows
                psi.EnvironmentVariables["USERPROFILE"] = homePath; 

                using (Process p = Process.Start(psi))
                {
                    string output = p.StandardOutput.ReadToEnd();
                    p.WaitForExit();

                    var lines = output.Split('\n');
                    foreach (var line in lines)
                    {
                        var t = line.Trim();
                        if (string.IsNullOrEmpty(t) || t.ToLower().StartsWith("quota")) continue;
                        
                        var parts = t.Split('\t');
                        if (parts.Length >= 4) {
                            int pct = 0;
                            int.TryParse(parts[2].Replace("%", "").Trim(), out pct);
                            res.Add(new Quota { Model = parts[0].Trim(), LimitType = parts[1].Trim(), Percent = pct });
                            continue;
                        }

                        var match = Regex.Match(t, @"^(.+?)\s{2,}(.+?)\s{2,}(\d+)%\s+(\S+)\s*$");
                        if (match.Success)
                        {
                            res.Add(new Quota {
                                Model = match.Groups[1].Value.Trim(),
                                LimitType = match.Groups[2].Value.Trim(),
                                Percent = int.Parse(match.Groups[3].Value)
                            });
                        }
                    }
                }
            } catch {}
            return res;
        }

        void Exit(object sender, EventArgs e)
        {
            trayIcon.Visible = false;
            Application.Exit();
        }
    }
}
