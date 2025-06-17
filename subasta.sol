// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
contract Subasta{
    address public owner;
    string public articulo;
    uint256 public tiempoInicio;
    uint256 public tiempoCierre;
    bool public finalizada;
    
    struct oferta {
        address oferente;
        uint256 monto; 
    }
    //guarda las ofertas realizadas por un usuario
    mapping (address =>uint256[]) public historialOfertas; 
    //guarda los reembolsos pendentes del oferante
    mapping (address => uint256 ) public reembolsosPendientes;
   // guarda la ultima oferta de un usuario
    mapping(address => uint256) public ultimaOferta;
    //guarda el total de eth enviado por un usuario
    mapping(address => uint256) public totalEnviado;
    oferta [] public ofertas;

    uint256 public ofertaInicial;
    uint256 public mejorOferta;
    address public ganador;
    modifier onlyOwner {require (owner == msg.sender, "sin acceso");_;}


    // la mejor oferta requiere ser 5% más de la mejor oferta anterior (100 + 5)
    uint256 constanteIncremento = 105;
   
    // se emitirá cuando exista una nueva oferta
    event nuevaOferta (address indexed oferente, uint256 monto);
    // se emitirá cuando finalice la subasta
    event subastaFinalizada (address ganador, uint256 montoGanador );

    // inicializa la subasta
    constructor  (string memory _articulo, uint256 _ofertaInicial) payable {
        owner = msg.sender;
        articulo = _articulo;
        tiempoInicio = block.timestamp;
        uint256 duracionMinutos = 15;
        tiempoCierre = tiempoInicio + (duracionMinutos * 1 minutes);
        ofertaInicial = _ofertaInicial;
        finalizada = false;
    }

    // función para hacer una oferta
    function ofertar () external payable {
        require (block.timestamp < tiempoCierre, "subasta ya finalizada" );
    // Se calcula la oferta mínima válida:
    // Si no hay ninguna oferta la oferta minima es 0
        uint256 ofertaMinima = mejorOferta == 0 
    //si ya existe una oferta, la nueva oferta minima será un 5% mayor a la mejor oferta  
            ? ofertaInicial 
            : (mejorOferta * constanteIncremento) / 100;       
        require (msg.value > ofertaMinima, "no puedes ofertar menos de lo requerido" );
    // Guardar el total enviado por el usuario
        totalEnviado[msg.sender] += msg.value;
 // Si ya hizo ofertas previas, se calcula el excedente
        if (ultimaOferta[msg.sender] > 0) {
            uint256 excedente = totalEnviado[msg.sender] - msg.value - ultimaOferta[msg.sender];
            if (excedente > 0) {
                reembolsosPendientes[msg.sender] += excedente;
            }
        }
    // Si hay un ganador anterior, guardar reembolso para él
        if (mejorOferta > 0 && ganador != msg.sender) {
            reembolsosPendientes[ganador] += mejorOferta;
        }
    // guarda en el mapping historialOfertas la nueva oferta del oferente     
        historialOfertas [msg.sender].push (msg.value);
        ofertas.push (oferta (msg.sender, msg.value));
        ultimaOferta[msg.sender] = msg.value;
        mejorOferta = msg.value ; // guarda en mejorOferta el monto más alto presente
        ganador = msg.sender; // establece al oferente como ganador momentaneo por defecto durante la subasta

    //extiende la subasta 10 minutos si quedan menos de 10 minutos al momento de la ultima oferta
        if (tiempoCierre - block.timestamp < 10 minutes) {
            tiempoCierre += 10 minutes;    
        }
    // emite evento nuevaOferta con la direccion del oferente y el monto pujado
        emit nuevaOferta(msg.sender, msg.value);
        
    // cierra la subasta si se supera el tiempo de duracion de la oferta 
        if (block.timestamp >= tiempoCierre)  {
            finalizada = true ;
        }
    }

    function retirarExcedente() external {
        require(!finalizada, "La subasta ya finalizo");
        uint256 total = totalEnviado[msg.sender];
        uint256 ultima = ultimaOferta[msg.sender];

        require(total > ultima, "No tienes excedente a retirar");

        uint256 excedente = total - ultima;
        totalEnviado[msg.sender] = ultima;

        payable(msg.sender).transfer(excedente);
    }

    // devuelve el ganador y su oferta
        function obtenerGanador() external view returns (address, uint256) {
            require (finalizada, "la subasta no ha finalizado");
            return (ganador, mejorOferta);
        }

    // davuelve la lista de ofertas 
    function verOfertas () external view returns (oferta [] memory) {
        return ofertas ;
    }
    function finalizarSubasta() external onlyOwner {
    require(block.timestamp >= tiempoCierre, "La subasta aun no ha terminado");
    require(!finalizada, "Ya esta finalizada");
    
    finalizada = true;

    // Emitir evento
    emit subastaFinalizada(ganador, mejorOferta);
}

    // permite retirar los reembolos pendientes menos el 2% de comisión
    function retirarReembolso () external {
        uint256 monto = reembolsosPendientes [msg.sender];
        require (monto > 0, "no tienes reembolos pendientes");
    // calcula el 2% de comisión del reembolso pendiente
        uint256 comision = (monto *2) /100;
        uint256 montoFinal = monto - comision ;
    // resetea el reembolos pendiente del usuario antes del transfer para evitar reentrancy attack
    reembolsosPendientes [msg.sender] = 0; 
    // transfiere el monto final 
    payable (msg.sender).transfer(montoFinal);  
    }   
    
   


}