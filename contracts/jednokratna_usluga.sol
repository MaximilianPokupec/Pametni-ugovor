// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Jednokratna_usluga{
    //Cijena usluge je u stablecoin valuti poput USDT
    IERC20 public valuta;
    uint public constant BROJ_SEKUNDI_U_DANU = 86400;
    //Stranke ugovora
    address public kupac;
    address public pruzateljUsluge;
    address public inspektor;
    //Puna cijena usluge
    uint256 public cijenaUsluge;
    //Broj dana od početka djelovanja ugovora
    uint public pocetniDatumUsluge;
    //Penali za prekoračenje ugovorenog roka
    uint256 public iznosPenala;
    //Datum na koji je kupac položio sredstva
    uint256 public datumPolozenihSredstva;
    //Datum kada je poduzetnik završio posao
    uint256 public datumIspunjenjaUsluge;
    //Zadnji dan roka za izvršenje usluge
    uint256 public datumRoka;
    //Status potpisa ugovornih stranaka
    bool public kupacJePotpisao = false;
    bool public pruzateljJePotpisao = false;
    //Status usluge
    enum Status {potrebna_akcija, Aktivan, Obavljen, Odobren, Osporen, Odbijen}
    Status public status;

    //Konstruktor ugovora
    constructor(
        address _ugovornaValuta,
        address _pruzatelj_usluge,
        address _inspektor,
        uint256 _cijenaUsluge,
        uint _datumPolozenihSredstva,
        uint256 _iznosPenala
    ) {
        valuta = IERC20(_ugovornaValuta);
        kupac = msg.sender;
        pruzateljUsluge = _pruzatelj_usluge;
        inspektor = _inspektor;
        cijenaUsluge = _cijenaUsluge;
        datumPolozenihSredstva = _datumPolozenihSredstva;
        iznosPenala = _iznosPenala;
        status = Status.potrebna_akcija;
    }
    //Kupac i pružatelj moraju potpisati ugovor prije početka djelovanja ugovora
    function potpisi() external {
        require(msg.sender == kupac || msg.sender == pruzateljUsluge, 
        "Samo kupac i pruzatelj mogu potpisivati ugovor");
        if (msg.sender == kupac){
            kupacJePotpisao = true;
        }else {
            pruzateljJePotpisao = true;
        }
    }
    // Kupac ima pravo započeti ugovor i deponirati potrebni iznos na pametni ugovor
    function zapocni_ugovor() external {
        require(msg.sender == kupac, "Samo kupac moze zapoceti ugovor");
        require(kupacJePotpisao && pruzateljJePotpisao, "Ugovor nije potpisan od strane obiju stranaka");
        require(valuta.balanceOf(msg.sender) >= cijenaUsluge, "Nedostatna kolicina valute za polaganje");
        bool uspjesnoPolaganjeNaUgovor = valuta.transferFrom(msg.sender, address(this), cijenaUsluge);
        require(uspjesnoPolaganjeNaUgovor, "Transfer sredstava nije uspio");

        pocetniDatumUsluge = block.timestamp;
        datumRoka = datumPolozenihSredstva + pocetniDatumUsluge * BROJ_SEKUNDI_U_DANU;

        status = Status.Aktivan;
    }
    //Posluzitelj postavlja uslugu obavljenom nakon izvršenja usluge
    function postavi_ugovor_obavljenim() external {
        require(msg.sender == pruzateljUsluge, "Samo pruzatelj moze postaviti ugovor obavljenim");
        require(status == Status.Aktivan, "Ugovor se moze postaviti obavljenim samo iz statusa 'Aktivan'");
        datumIspunjenjaUsluge = block.timestamp;
        status = Status.Obavljen;
    }

    //Funkcija za izračunavanje dana ukoliko obavljanje usluge premašuje ugovoreni rok
    function getPropusteniDani() public view returns(uint){
        uint256 brojDana = datumIspunjenjaUsluge == 0 ? block.timestamp : datumIspunjenjaUsluge;
        if (brojDana <= datumRoka){
            return 0;
        } else {
            return (brojDana - datumRoka) / BROJ_SEKUNDI_U_DANU;
        }
    }

    //Interna funkcija za isplaćivanje sredstava strankama
    function isplati_stranke(bool odobreno) internal {
        if(!odobreno) {
            bool uspjesan_prijenos = valuta.transfer(kupac, cijenaUsluge);
            require(uspjesan_prijenos,"Povrat sredstava sa ugovora nije uspio");
            return;
        }

       

        //Ukoliko je pružatelj obavio uslugu u roku, dobije sredstva u potpunosti, inače vrši povrat i penalizira pružatelja
        if (datumIspunjenjaUsluge <= datumRoka){
            bool uspjesan_prijenos = valuta.transfer(pruzateljUsluge, cijenaUsluge);
            require(uspjesan_prijenos,"Prijenos sredstava pruzatelju nije uspio");
        } else {
            uint propusteniDani = getPropusteniDani();
            uint256 kolicinaPenala = iznosPenala * propusteniDani;
            if (kolicinaPenala < cijenaUsluge){
                bool uspjesan_umanjen_prijenos = valuta.transfer(pruzateljUsluge, cijenaUsluge - kolicinaPenala);
                require(uspjesan_umanjen_prijenos, "Prijenos pruzatelju neuspjesan");

                bool povrat_radnja = valuta.transfer(kupac, kolicinaPenala);
                require(povrat_radnja, "Povrat sredstava kupcu neuspjesan");
            } else {
                bool uspjesan_transfer = valuta.transfer(kupac, cijenaUsluge);
                require(uspjesan_transfer, "Povrat sredstava kupcu neuspjesan");
            }
        }
    }
     //Funkcija za dohvaćanje ugovornih stranaka
    function getUgovorneStranke() public view returns(address,address,address){
            return(kupac,pruzateljUsluge,inspektor);
    }
    //funkcija za dohvaćanje cijene usluge
    function getCijenaUsluge() public view returns(uint256){
            return cijenaUsluge;
    }
    //funkcija za dohvaćanje datuma početka obavljanja usluge
    function getPocetniDatumUsluge() public view returns(uint){
        return pocetniDatumUsluge;
    }
    //Funkcija za dohvaćanje trenutnog vremena pametnog ugovora
    function getVrijeme() public view returns (uint256){
        return block.timestamp;
    }
    //funkcija za dohvaćanje datuma polaganja sredstava kupca na ugovor
    function getDatumPolozenihSredstva() public view returns(uint256){
        return datumPolozenihSredstva;
    }
    //Funkcija za dohvaćanje statusa potpisa ugovora
    function getStatusPotpisa() public view returns (bool,bool){
        return(kupacJePotpisao, pruzateljJePotpisao);
    }
    //Funkcija za dohvaćanje statusa usluge
    function getStatusUsluge() public view returns(Status){
        return status;
    }
    //funkcija za dohvaćanje adrese za polaganje sredstava
    function getValutaAdresa() public view returns (address){
        return address(valuta);
    }
    
    // Kupac odobrava odrađenu uslugu, novac se šalje pružatelju
    function odobri_uslugu() external {
        require(msg.sender == kupac, "Samo kupac moze odobriti uslugu");
        require(status==Status.Obavljen, "Usluga nije obavljena");
        status = Status.Odobren;
        isplati_stranke(true);
    }
    //Kupac može ovom funkcijom označiti odrađenu uslugu neodrađenom do kraja
    function postavi_uslugu_osporivom() external {
        require(msg.sender == kupac, "Samo kupac moze osporiti obavljenu uslugu");
        require(status == Status.Obavljen, "Usluga nije obavljena");
        status = Status.Osporen;
    }

    //Inspektor razrješava situaciju u korist kupca ili pružatelja
    function razrijesiSpor(bool odobreno) external {
        require(msg.sender == inspektor, "Samo inspektor moze razrijesiti sporove");
        require(status == Status.Osporen, "Nema spora za razrijesiti");
        if(odobreno) {
            status = Status.Odobren;
            isplati_stranke(true);
        } else {
            status = Status.Odbijen;
            isplati_stranke(false);
        }
    }
    //Kupac može tražiti povrat ukoliko vrijednost penala prelaze cijenu same usluge
    function povrat() external {
        require(msg.sender == kupac, "Samo kupac ima pravo na povrat");
        require(
            status == Status.Aktivan || status == Status.Obavljen || status == Status.Osporen,
            "Status ugovora mora biti Aktivan, Obavljen ili osporen"
        );
        uint propusteniDani = getPropusteniDani();
        uint256 ukupanPovrat = iznosPenala * propusteniDani;
        require(ukupanPovrat > cijenaUsluge,"Nakupljeni penali jos ne prelaze cijenu usluge");
        bool uspjesan_prijenos = valuta.transfer(kupac, cijenaUsluge);
        require(uspjesan_prijenos, "Prijenos polozenih sredstava kupcu neuspjesan");
        status = Status.Odbijen;
    }
}