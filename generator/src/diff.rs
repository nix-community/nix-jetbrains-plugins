use ansi_term::{Color, Style};
use anyhow::{Context, anyhow};
use clap::Args;
use gix::bstr::ByteSlice;
use gix::object::tree::diff::Change;
use pathdiff::diff_paths;
use std::collections::{BTreeMap, HashMap};
use std::fs::canonicalize;
use std::hash::Hash;
use std::ops::ControlFlow;
use std::path::Path;

// <plugin>: (<ide>, <old_version>, <new_version>)
type ChangeList = BTreeMap<String, Vec<(String, Option<String>, Option<String>)>>;

#[derive(Debug, Args)]
pub struct DiffArgs {
    /// Print the names of changed plugins as a JSON array
    #[clap(long)]
    names_json: bool,
    /// Base reference
    old_tree: String,
    /// Reference to compare to
    new_tree: String,
}

pub async fn run(plugins_path: &Path, args: DiffArgs) -> anyhow::Result<()> {
    let repo = gix::discover(plugins_path)?;
    let workdir = repo
        .workdir()
        .ok_or_else(|| anyhow!("repo has no workdir"))?;
    let plugins_path_abs = canonicalize(plugins_path).context("failed to resolve plugins path")?;
    let plugins_path_in_workdir = diff_paths(
        plugins_path_abs,
        canonicalize(workdir).context("failed to resolve repo path")?,
    )
    .ok_or_else(|| anyhow!("failed to find plugins path in repo"))?
    .to_string_lossy()
    .to_string();

    let old_tree = repo
        .rev_parse_single(&*args.old_tree)?
        .object()?
        .peel_to_tree()?;
    let new_tree = repo
        .rev_parse_single(&*args.new_tree)?
        .object()?
        .peel_to_tree()?;

    let mut changed: ChangeList = BTreeMap::new();

    old_tree
        .changes()?
        .for_each_to_obtain_tree(&new_tree, |change| {
            let loc = change.location().to_str_lossy();

            if let Some(ide_path) = loc.strip_prefix(&format!("{plugins_path_in_workdir}/ides/"))
                && let Some(ide_name) = ide_path.strip_suffix(".json")
                && !ide_name.contains('/')
            {
                match change {
                    Change::Modification {
                        previous_id, id, ..
                    } => {
                        let old_blob = previous_id.object()?.into_blob();
                        let new_blob = id.object()?.into_blob();
                        process_ide_file(&mut changed, &old_blob.data, &new_blob.data, ide_name)?;
                    }
                    Change::Rewrite { source_id, id, .. } => {
                        let old_blob = source_id.object()?.into_blob();
                        let new_blob = id.object()?.into_blob();
                        process_ide_file(&mut changed, &old_blob.data, &new_blob.data, ide_name)?;
                    }
                    Change::Addition { id, .. } => {
                        let new_blob = id.object()?.into_blob();
                        process_ide_file(&mut changed, b"{}", &new_blob.data, ide_name)?;
                    }
                    Change::Deletion { id, .. } => {
                        let old_blob = id.object()?.into_blob();
                        process_ide_file(&mut changed, &old_blob.data, b"{}", ide_name)?;
                    }
                };
            }
            Ok::<_, anyhow::Error>(ControlFlow::Continue(()))
        })?;

    if args.names_json {
        print_json(changed)
    } else {
        print_pretty(changed)
    }
}

fn process_ide_file(
    changes: &mut ChangeList,
    ide_file_before: &[u8],
    ide_file_after: &[u8],
    ide_name: &str,
) -> anyhow::Result<()> {
    let plugins_versions_before: HashMap<String, String> =
        serde_json::from_reader(ide_file_before)?;
    let plugins_versions_after: HashMap<String, String> = serde_json::from_slice(ide_file_after)?;

    for (plugin_name, old_v, new_v) in diff_maps(&plugins_versions_before, &plugins_versions_after)
    {
        let value = (
            ide_name.to_string(),
            old_v.map(ToString::to_string),
            new_v.map(ToString::to_string),
        );
        changes.entry(plugin_name.clone()).or_default();
        changes.get_mut(plugin_name).unwrap().push(value);
    }

    Ok(())
}

fn diff_maps<'a, K: Eq + Hash, V: Eq>(
    old: &'a HashMap<K, V>,
    new: &'a HashMap<K, V>,
) -> impl Iterator<Item = (&'a K, Option<&'a V>, Option<&'a V>)> {
    let changed_or_removed = old.iter().filter_map(|(k, v_old)| {
        let v_new = new.get(k);
        (Some(v_old) != v_new).then_some((k, Some(v_old), v_new))
    });

    let added = new
        .iter()
        .filter_map(|(k, v_new)| (!old.contains_key(k)).then_some((k, None, Some(v_new))));

    changed_or_removed.chain(added)
}

fn print_json(changes: ChangeList) -> anyhow::Result<()> {
    serde_json::to_writer(std::io::stdout(), &changes.keys().collect::<Box<[_]>>())
        .map_err(Into::into)
}

fn print_pretty(changes: ChangeList) -> anyhow::Result<()> {
    for (plugin, changes) in &changes {
        println!("{}", Style::new().bold().fg(Color::Green).paint(plugin));
        for (ide, old_version, new_version) in changes {
            match (old_version, new_version) {
                (Some(old_version), Some(new_version)) => {
                    println!(
                        "  - {}: {} -> {}",
                        Style::new().bold().paint(ide),
                        old_version,
                        new_version
                    );
                }
                (Some(old_version), None) => {
                    println!(
                        "  - {}: {} -> {}",
                        Style::new().bold().paint(ide),
                        old_version,
                        Style::new().fg(Color::Red).paint("<removed>")
                    );
                }
                (None, Some(new_version)) => {
                    println!(
                        "  - {}: init at {}",
                        Style::new().bold().paint(ide),
                        Style::new().fg(Color::Green).paint(new_version)
                    );
                }
                (None, None) => unreachable!(),
            }
        }
    }
    Ok(())
}
