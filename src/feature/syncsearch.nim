import
  algorithm, future, options, sequtils, strutils,
  "../args", "../aur", "../config", "../common", "../format", "../package",
    "../pacman", "../utils",
  "../wrapper/alpm"

proc handleSyncSearch*(args: seq[Argument], config: Config): int =
  let (_, callArgs) = checkAndRefresh(config.color, args)

  let quiet = args.check((some("q"), "quiet"))

  let (aurPackages, aerrors) = findAurPackages(args.targets)
  for e in aerrors: printError(config.color, e)

  type Package = tuple[rpcInfo: RpcPackageInfo, installedVersion: Option[string]]

  proc checkLocalPackages: seq[Package] =
    if quiet:
      aurPackages.map(pkg => (pkg, none(string)))
    elif aurPackages.len > 0:
      withAlpm(config.root, config.db, newSeq[string](), config.arch, handle, dbs, errors):
        for e in errors: printError(config.color, e)

        aurPackages.map(proc (rpcInfo: RpcPackageInfo): Package =
          let pkg = handle.local[rpcInfo.name]
          if pkg != nil:
            (rpcInfo, some($pkg.version))
          else:
            (rpcInfo, none(string)))
    else:
      @[]

  let pkgs = checkLocalPackages()
    .sorted((a, b) => cmp(a.rpcInfo.name, b.rpcInfo.name))

  var code = min(aerrors.len, 1)
  if pkgs.len == 0:
    if code == 0:
      pacmanExec(false, config.color, callArgs)
    else:
      discard pacmanRun(false, config.color, callArgs)
      code
  else:
    discard pacmanRun(false, config.color, callArgs)

    for pkg in pkgs:
      if quiet:
        echo(pkg.rpcInfo.name)
      else:
        printPackageSearch(config.color, "aur", pkg.rpcInfo.name,
          pkg.rpcInfo.version, pkg.installedVersion, pkg.rpcInfo.description,
          some(formatPkgRating(pkg.rpcInfo.votes, pkg.rpcInfo.popularity)))
    0
