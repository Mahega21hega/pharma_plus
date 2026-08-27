import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_data.dart';
import '../theme/app_theme.dart';

class MedicamentFormScreen extends StatefulWidget {
  final Medicament? medicament;
  const MedicamentFormScreen({super.key, this.medicament});

  @override
  State<MedicamentFormScreen> createState() => _MedicamentFormScreenState();
}

class _MedicamentFormScreenState extends State<MedicamentFormScreen> {
  // Formulaire découpé en 2 étapes avec barre de progression : un long
  // formulaire à 10 champs affiché d'un bloc décourage et augmente les
  // erreurs de saisie. Chaque étape a sa propre clé de validation pour ne
  // bloquer que sur les champs réellement visibles à l'écran.
  final _formKeyEtape1 = GlobalKey<FormState>();
  final _formKeyEtape2 = GlobalKey<FormState>();
  int _etape = 0;

  late TextEditingController _nom;
  late TextEditingController _dci;
  late TextEditingController _categorie;
  late TextEditingController _fabricant;
  late TextEditingController _prixAchat;
  late TextEditingController _prixVente;
  late TextEditingController _stock;
  late TextEditingController _numeroLot;
  late TextEditingController _codeBarres;
  late TextEditingController _emplacement;
  late DateTime _dateFabrication;
  late DateTime _dateExpiration;
  bool _surOrdonnance = false;

  bool get _estModification => widget.medicament != null;

  @override
  void initState() {
    super.initState();
    final m = widget.medicament;
    _nom = TextEditingController(text: m?.nomCommercial ?? '');
    _dci = TextEditingController(text: m?.dci ?? '');
    _categorie = TextEditingController(text: m?.categorie ?? '');
    _fabricant = TextEditingController(text: m?.fabricant ?? '');
    _prixAchat = TextEditingController(text: m?.prixAchat.toStringAsFixed(0) ?? '');
    _prixVente = TextEditingController(text: m?.prixVente.toStringAsFixed(0) ?? '');
    _stock = TextEditingController(text: m?.stock.toString() ?? '');
    _numeroLot = TextEditingController(text: m?.numeroLot ?? '');
    _codeBarres = TextEditingController(text: m?.codeBarres ?? '');
    _emplacement = TextEditingController(text: m?.emplacement ?? '');
    _dateFabrication = m?.dateFabrication ?? DateTime.now();
    _dateExpiration = m?.dateExpiration ?? DateTime.now().add(const Duration(days: 365));
    _surOrdonnance = m?.surOrdonnance ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_estModification ? 'Modifier le médicament' : 'Ajouter un médicament')),
      body: Column(
        children: [
          _barreDeProgression(),
          Expanded(
            child: IndexedStack(
              index: _etape,
              children: [
                _etape1(),
                _etape2(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Barre de progression à 2 pastilles reliées par un trait, avec le
  /// nombre de l'étape courante mis en évidence (cf. le repère "Étape X/2"
  /// des formulaires multi-étapes).
  Widget _barreDeProgression() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          _pastille(0, 'Informations'),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: _etape > 0 ? AppColors.primary : AppColors.textMuted.withOpacity(0.3),
            ),
          ),
          _pastille(1, 'Stock & Prix'),
        ],
      ),
    );
  }

  Widget _pastille(int index, String label) {
    final actif = _etape == index;
    final complete = _etape > index;
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: (actif || complete) ? AppColors.primary : AppColors.textMuted.withOpacity(0.25),
          child: complete
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text('${index + 1}', style: TextStyle(color: actif ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: actif ? AppColors.primary : AppColors.textMuted, fontWeight: actif ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }

  Widget _etape1() {
    return Form(
      key: _formKeyEtape1,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text('Informations générales', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Identité du médicament', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 18),
          _field('Nom commercial', _nom),
          _field('DCI (nom générique)', _dci),
          _field('Catégorie', _categorie),
          _field('Fabricant', _fabricant),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_formKeyEtape1.currentState!.validate()) {
                  setState(() => _etape = 1);
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Suivant'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _etape2() {
    return Form(
      key: _formKeyEtape2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text('Stock & Prix', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Traçabilité et disponibilité en rayon', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 18),
          // Les deux prix sont regroupés côte à côte : ils forment une
          // même unité d'information (marge), un espacement plus large
          // sépare ce groupe du reste des champs.
          Row(
            children: [
              Expanded(child: _field("Prix d'achat (Ar)", _prixAchat, numeric: true)),
              const SizedBox(width: 10),
              Expanded(child: _field('Prix de vente (Ar)', _prixVente, numeric: true)),
            ],
          ),
          const SizedBox(height: 4),
          _field('Quantité en stock', _stock, numeric: true),
          const SizedBox(height: 12),
          _field('Numéro de lot', _numeroLot),
          _field('Code-barres', _codeBarres),
          _field('Emplacement dans la pharmacie', _emplacement),
          const SizedBox(height: 8),
          _dateTile('Date de fabrication', _dateFabrication, (d) => setState(() => _dateFabrication = d)),
          _dateTile('Date d\'expiration', _dateExpiration, (d) => setState(() => _dateExpiration = d)),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Médicament sur ordonnance'),
            value: _surOrdonnance,
            onChanged: (v) => setState(() => _surOrdonnance = v),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _etape = 0),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Précédent'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _enregistrer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(_estModification ? 'Enregistrer les modifications' : 'Ajouter le médicament'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
      ),
    );
  }

  Widget _dateTile(String label, DateTime value, ValueChanged<DateTime> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(DateFormat('dd/MM/yyyy').format(value)),
      trailing: const Icon(Icons.calendar_today_rounded, size: 18),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2015),
          lastDate: DateTime(2035),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }

  void _enregistrer() {
    if (!_formKeyEtape2.currentState!.validate()) return;
    final data = context.read<AppData>();

    final medicament = Medicament(
      id: widget.medicament?.id ?? data.genererIdMedicament(),
      nomCommercial: _nom.text,
      dci: _dci.text,
      categorie: _categorie.text,
      fabricant: _fabricant.text,
      prixAchat: double.tryParse(_prixAchat.text) ?? 0,
      prixVente: double.tryParse(_prixVente.text) ?? 0,
      stock: int.tryParse(_stock.text) ?? 0,
      dateFabrication: _dateFabrication,
      dateExpiration: _dateExpiration,
      numeroLot: _numeroLot.text,
      codeBarres: _codeBarres.text,
      emplacement: _emplacement.text,
      surOrdonnance: _surOrdonnance,
    );

    if (_estModification) {
      data.modifierMedicament(medicament);
    } else {
      data.ajouterMedicament(medicament);
    }
    Navigator.pop(context);
  }
}
