module.exports = {
  appFolderName: 'ElderSoulsRPGAlpha',
  downloads: {
    server: {
      id: '12juSipjaUSvAxL9S39czLFeN5G7d-2NE',
      fileName: 'elder-souls-rpg-alpha-server-source.zip',
      folderName: 'matrix-server'
    },
    client: {
      id: '1OkZjJ4FvaOXeo-XQlBOLKUlan_EVBA5X',
      fileName: 'elder-souls-rpg-alpha-client-source.zip',
      folderName: 'matrix-client'
    },
    cache: {
      id: '1fXs8vni-LtFvuUT1Ol4R37KsZMGaHv62',
      fileName: 'elder-souls-rpg-alpha-cache.zip',
      folderName: 'cache'
    }
  },
  serverCacheTarget: ['data', 'cache'],
  launch: {
    loginTask: 'runLogin',
    gameTask: 'runGame',
    clientTask: 'run'
  }
};
